package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"strings"
	"unicode/utf8"

	"golang.org/x/crypto/bcrypt"
)

type ctxKey struct{}

// currentUser возвращает пользователя, прошедшего проверку токена.
func currentUser(r *http.Request) *User {
	u, _ := r.Context().Value(ctxKey{}).(*User)
	return u
}

func newToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// auth — middleware: проверяет токен из заголовка Authorization: Bearer <token>.
// Заблокированным пользователям доступ запрещается.
func (a *App) auth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		if token == "" {
			writeError(w, http.StatusUnauthorized, "Требуется авторизация")
			return
		}
		var u User
		var blocked int
		err := a.DB.QueryRow(`SELECT u.id,u.login,u.name,u.role,u.blocked,u.created_at
			FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token=?`, token).
			Scan(&u.ID, &u.Login, &u.Name, &u.Role, &blocked, &u.CreatedAt)
		if isNotFound(err) {
			writeError(w, http.StatusUnauthorized, "Сессия истекла, войдите снова")
			return
		}
		if err != nil {
			serverError(w, err)
			return
		}
		if blocked == 1 {
			writeError(w, http.StatusForbidden, "Ваш аккаунт заблокирован администратором")
			return
		}
		next(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, &u)))
	}
}

// admin — middleware: доступ только для администратора.
func (a *App) admin(next http.HandlerFunc) http.HandlerFunc {
	return a.auth(func(w http.ResponseWriter, r *http.Request) {
		if currentUser(r).Role != "admin" {
			writeError(w, http.StatusForbidden, "Действие доступно только администратору")
			return
		}
		next(w, r)
	})
}

type credentials struct {
	Login    string `json:"login"`
	Password string `json:"password"`
	Name     string `json:"name"`
}

// POST /api/auth/register — регистрация. Всегда создаётся клиент:
// роль администратора нельзя выбрать при регистрации.
func (a *App) register(w http.ResponseWriter, r *http.Request) {
	var c credentials
	if !decodeJSON(w, r, &c) {
		return
	}
	c.Login = strings.ToLower(strings.TrimSpace(c.Login))
	c.Name = strings.TrimSpace(c.Name)
	switch {
	case utf8.RuneCountInString(c.Login) < 3 || utf8.RuneCountInString(c.Login) > 30:
		writeError(w, http.StatusBadRequest, "Логин должен содержать от 3 до 30 символов")
		return
	case strings.ContainsAny(c.Login, " \t"):
		writeError(w, http.StatusBadRequest, "Логин не должен содержать пробелов")
		return
	case utf8.RuneCountInString(c.Password) < 6:
		writeError(w, http.StatusBadRequest, "Пароль должен содержать не менее 6 символов")
		return
	case c.Name == "":
		writeError(w, http.StatusBadRequest, "Укажите имя")
		return
	}
	var exists int
	if err := a.DB.QueryRow(`SELECT COUNT(*) FROM users WHERE login=?`, c.Login).Scan(&exists); err != nil {
		serverError(w, err)
		return
	}
	if exists > 0 {
		writeError(w, http.StatusConflict, "Пользователь с таким логином уже существует")
		return
	}
	h, err := hashPassword(c.Password)
	if err != nil {
		serverError(w, err)
		return
	}
	res, err := a.DB.Exec(`INSERT INTO users(login,password_hash,name,role) VALUES(?,?,?, 'client')`, c.Login, h, c.Name)
	if err != nil {
		serverError(w, err)
		return
	}
	id, _ := res.LastInsertId()
	a.issueSession(w, id, http.StatusCreated)
}

// POST /api/auth/login — вход. Роль пользователя сервер определяет сам
// и возвращает её в ответе, клиент выбирает интерфейс по этой роли.
func (a *App) login(w http.ResponseWriter, r *http.Request) {
	var c credentials
	if !decodeJSON(w, r, &c) {
		return
	}
	c.Login = strings.ToLower(strings.TrimSpace(c.Login))
	if c.Login == "" || c.Password == "" {
		writeError(w, http.StatusBadRequest, "Введите логин и пароль")
		return
	}
	var id int64
	var hash string
	var blocked int
	err := a.DB.QueryRow(`SELECT id,password_hash,blocked FROM users WHERE login=?`, c.Login).Scan(&id, &hash, &blocked)
	if isNotFound(err) || (err == nil && bcrypt.CompareHashAndPassword([]byte(hash), []byte(c.Password)) != nil) {
		writeError(w, http.StatusUnauthorized, "Неверный логин или пароль")
		return
	}
	if err != nil {
		serverError(w, err)
		return
	}
	if blocked == 1 {
		writeError(w, http.StatusForbidden, "Ваш аккаунт заблокирован администратором")
		return
	}
	a.issueSession(w, id, http.StatusOK)
}

func (a *App) issueSession(w http.ResponseWriter, userID int64, status int) {
	token, err := newToken()
	if err != nil {
		serverError(w, err)
		return
	}
	if _, err := a.DB.Exec(`INSERT INTO sessions(token,user_id) VALUES(?,?)`, token, userID); err != nil {
		serverError(w, err)
		return
	}
	u, err := a.getUser(userID)
	if err != nil {
		serverError(w, err)
		return
	}
	writeJSON(w, status, map[string]any{"token": token, "user": u})
}

func (a *App) getUser(id int64) (*User, error) {
	var u User
	var blocked int
	err := a.DB.QueryRow(`SELECT id,login,name,role,blocked,created_at FROM users WHERE id=?`, id).
		Scan(&u.ID, &u.Login, &u.Name, &u.Role, &blocked, &u.CreatedAt)
	u.Blocked = blocked == 1
	return &u, err
}

// GET /api/auth/me — текущий пользователь (восстановление сеанса).
func (a *App) me(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, currentUser(r))
}

// POST /api/auth/logout — удаление сессии.
func (a *App) logout(w http.ResponseWriter, r *http.Request) {
	token := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
	if _, err := a.DB.Exec(`DELETE FROM sessions WHERE token=?`, token); err != nil {
		serverError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
