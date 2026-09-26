package main

import (
	"net/http"
	"strings"
	"unicode/utf8"
)

// ───────────────────────── Избранное ─────────────────────────

// POST /api/favorites/{id} — добавить модель в избранное текущего пользователя.
func (a *App) addFavorite(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var exists int
	if err := a.DB.QueryRow(`SELECT COUNT(*) FROM shoes WHERE id=? AND deleted=0`, id).Scan(&exists); err != nil {
		serverError(w, err)
		return
	}
	if exists == 0 {
		writeError(w, http.StatusNotFound, "Модель не найдена")
		return
	}
	if _, err := a.DB.Exec(`INSERT OR IGNORE INTO favorites(user_id,shoe_id) VALUES(?,?)`, currentUser(r).ID, id); err != nil {
		serverError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// DELETE /api/favorites/{id} — убрать модель из избранного.
func (a *App) removeFavorite(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	if _, err := a.DB.Exec(`DELETE FROM favorites WHERE user_id=? AND shoe_id=?`, currentUser(r).ID, id); err != nil {
		serverError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ───────────────────────── Отзывы ─────────────────────────

// GET /api/shoes/{id}/reviews
func (a *App) listReviews(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	rows, err := a.DB.Query(`SELECT r.id,r.shoe_id,r.user_id,u.name,r.rating,r.text,r.created_at
		FROM reviews r JOIN users u ON u.id=r.user_id WHERE r.shoe_id=? ORDER BY r.id DESC`, id)
	if err != nil {
		serverError(w, err)
		return
	}
	defer rows.Close()
	list := []Review{}
	for rows.Next() {
		var rv Review
		if err := rows.Scan(&rv.ID, &rv.ShoeID, &rv.UserID, &rv.UserName, &rv.Rating, &rv.Text, &rv.CreatedAt); err != nil {
			serverError(w, err)
			return
		}
		list = append(list, rv)
	}
	writeJSON(w, http.StatusOK, list)
}

// POST /api/shoes/{id}/reviews — оставить отзыв (один на пользователя, повторный заменяет старый).
func (a *App) addReview(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var in struct {
		Rating int    `json:"rating"`
		Text   string `json:"text"`
	}
	if !decodeJSON(w, r, &in) {
		return
	}
	in.Text = strings.TrimSpace(in.Text)
	if in.Rating < 1 || in.Rating > 5 {
		writeError(w, http.StatusBadRequest, "Оценка должна быть от 1 до 5")
		return
	}
	if utf8.RuneCountInString(in.Text) > 1000 {
		writeError(w, http.StatusBadRequest, "Отзыв не должен превышать 1000 символов")
		return
	}
	u := currentUser(r)
	if _, err := a.findShoe(id, u.ID); err != nil {
		if isNotFound(err) {
			writeError(w, http.StatusNotFound, "Модель не найдена")
			return
		}
		serverError(w, err)
		return
	}
	tx, err := a.DB.Begin()
	if err != nil {
		serverError(w, err)
		return
	}
	defer tx.Rollback()
	if _, err := tx.Exec(`DELETE FROM reviews WHERE shoe_id=? AND user_id=?`, id, u.ID); err != nil {
		serverError(w, err)
		return
	}
	if _, err := tx.Exec(`INSERT INTO reviews(shoe_id,user_id,rating,text) VALUES(?,?,?,?)`, id, u.ID, in.Rating, in.Text); err != nil {
		serverError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		serverError(w, err)
		return
	}
	w.WriteHeader(http.StatusCreated)
}

// DELETE /api/reviews/{id} — удалить отзыв (автор или администратор).
func (a *App) deleteReview(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	u := currentUser(r)
	var owner int64
	err := a.DB.QueryRow(`SELECT user_id FROM reviews WHERE id=?`, id).Scan(&owner)
	if isNotFound(err) {
		writeError(w, http.StatusNotFound, "Отзыв не найден")
		return
	}
	if err != nil {
		serverError(w, err)
		return
	}
	if owner != u.ID && u.Role != "admin" {
		writeError(w, http.StatusForbidden, "Можно удалить только свой отзыв")
		return
	}
	if _, err := a.DB.Exec(`DELETE FROM reviews WHERE id=?`, id); err != nil {
		serverError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ───────────────────────── Пользователи (admin) ─────────────────────────

// GET /api/users — список пользователей.
func (a *App) listUsers(w http.ResponseWriter, r *http.Request) {
	rows, err := a.DB.Query(`SELECT id,login,name,role,blocked,created_at FROM users ORDER BY role, id`)
	if err != nil {
		serverError(w, err)
		return
	}
	defer rows.Close()
	list := []User{}
	for rows.Next() {
		var u User
		var blocked int
		if err := rows.Scan(&u.ID, &u.Login, &u.Name, &u.Role, &blocked, &u.CreatedAt); err != nil {
			serverError(w, err)
			return
		}
		u.Blocked = blocked == 1
		list = append(list, u)
	}
	writeJSON(w, http.StatusOK, list)
}

// PUT /api/users/{id}/block и /unblock — блокировка клиента.
// Список заблокированных хранится в БД и сохраняется между сеансами.
func (a *App) setBlocked(blocked bool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, ok := pathID(w, r)
		if !ok {
			return
		}
		target, err := a.getUser(id)
		if isNotFound(err) {
			writeError(w, http.StatusNotFound, "Пользователь не найден")
			return
		}
		if err != nil {
			serverError(w, err)
			return
		}
		if target.Role == "admin" {
			writeError(w, http.StatusBadRequest, "Нельзя заблокировать администратора")
			return
		}
		if _, err := a.DB.Exec(`UPDATE users SET blocked=? WHERE id=?`, boolToInt(blocked), id); err != nil {
			serverError(w, err)
			return
		}
		if blocked {
			// Завершаем все активные сессии заблокированного пользователя.
			if _, err := a.DB.Exec(`DELETE FROM sessions WHERE user_id=?`, id); err != nil {
				serverError(w, err)
				return
			}
		}
		w.WriteHeader(http.StatusNoContent)
	}
}

// GET /api/stats — сводка для панели администратора.
func (a *App) stats(w http.ResponseWriter, r *http.Request) {
	var s struct {
		Shoes     int `json:"shoes"`
		Deleted   int `json:"deleted"`
		Clients   int `json:"clients"`
		Blocked   int `json:"blocked"`
		Pending   int `json:"pending_orders"`
		Orders    int `json:"orders"`
		Reviews   int `json:"reviews"`
		Favorites int `json:"favorites"`
	}
	err := a.DB.QueryRow(`SELECT
		(SELECT COUNT(*) FROM shoes WHERE deleted=0),
		(SELECT COUNT(*) FROM shoes WHERE deleted=1),
		(SELECT COUNT(*) FROM users WHERE role='client'),
		(SELECT COUNT(*) FROM users WHERE blocked=1),
		(SELECT COUNT(*) FROM orders WHERE status='pending'),
		(SELECT COUNT(*) FROM orders),
		(SELECT COUNT(*) FROM reviews),
		(SELECT COUNT(*) FROM favorites)`).
		Scan(&s.Shoes, &s.Deleted, &s.Clients, &s.Blocked, &s.Pending, &s.Orders, &s.Reviews, &s.Favorites)
	if err != nil {
		serverError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, s)
}
