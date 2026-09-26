package main

import (
	"database/sql"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strconv"
)

// App хранит зависимости обработчиков.
type App struct {
	DB *sql.DB
}

// apiError — единый формат ошибки для клиента.
type apiError struct {
	Error string `json:"error"`
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("ошибка сериализации ответа: %v", err)
	}
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, apiError{Error: msg})
}

// serverError логирует внутреннюю ошибку и отдаёт клиенту обобщённое сообщение.
func serverError(w http.ResponseWriter, err error) {
	log.Printf("внутренняя ошибка: %v", err)
	writeError(w, http.StatusInternalServerError, "Внутренняя ошибка сервера")
}

// decodeJSON читает тело запроса (не более 1 МБ) в структуру.
func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		writeError(w, http.StatusBadRequest, "Некорректный JSON в теле запроса")
		return false
	}
	return true
}

// pathID извлекает числовой параметр {id} из пути.
func pathID(w http.ResponseWriter, r *http.Request) (int64, bool) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "Некорректный идентификатор")
		return 0, false
	}
	return id, true
}

func isNotFound(err error) bool { return errors.Is(err, sql.ErrNoRows) }

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
