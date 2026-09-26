package main

import (
	"net/http"
	"regexp"
	"slices"
	"strings"
	"unicode/utf8"
)

var phoneRe = regexp.MustCompile(`^\+?[0-9()\-\s]{10,20}$`)

const orderSelect = `
SELECT o.id,o.user_id,u.name,o.shoe_id,s.name,s.brand,s.image_url,s.price,o.size,o.phone,o.comment,
       o.status,o.admin_comment,o.seen_by_admin,o.seen_by_client,o.created_at,o.updated_at
FROM orders o JOIN users u ON u.id=o.user_id JOIN shoes s ON s.id=o.shoe_id`

// POST /api/orders — клиент бронирует пару нужного размера.
// Заявка появляется у администратора как новое уведомление.
func (a *App) createOrder(w http.ResponseWriter, r *http.Request) {
	u := currentUser(r)
	if u.Role != "client" {
		writeError(w, http.StatusForbidden, "Бронирование доступно только клиентам")
		return
	}
	var in struct {
		ShoeID  int64  `json:"shoe_id"`
		Size    string `json:"size"`
		Phone   string `json:"phone"`
		Comment string `json:"comment"`
	}
	if !decodeJSON(w, r, &in) {
		return
	}
	in.Phone = strings.TrimSpace(in.Phone)
	in.Comment = strings.TrimSpace(in.Comment)
	if !phoneRe.MatchString(in.Phone) {
		writeError(w, http.StatusBadRequest, "Введите корректный номер телефона")
		return
	}
	if utf8.RuneCountInString(in.Comment) > 500 {
		writeError(w, http.StatusBadRequest, "Комментарий не должен превышать 500 символов")
		return
	}
	s, err := a.findShoe(in.ShoeID, u.ID)
	if isNotFound(err) || (err == nil && s.Deleted) {
		writeError(w, http.StatusNotFound, "Модель не найдена")
		return
	}
	if err != nil {
		serverError(w, err)
		return
	}
	if !s.InStock {
		writeError(w, http.StatusConflict, "Модели нет в наличии")
		return
	}
	if !slices.Contains(s.Sizes, in.Size) {
		writeError(w, http.StatusBadRequest, "Выбранный размер недоступен")
		return
	}
	var dup int
	if err := a.DB.QueryRow(`SELECT COUNT(*) FROM orders WHERE user_id=? AND shoe_id=? AND size=? AND status='pending'`,
		u.ID, in.ShoeID, in.Size).Scan(&dup); err != nil {
		serverError(w, err)
		return
	}
	if dup > 0 {
		writeError(w, http.StatusConflict, "Вы уже забронировали эту модель в таком размере — дождитесь ответа")
		return
	}
	res, err := a.DB.Exec(`INSERT INTO orders(user_id,shoe_id,size,phone,comment) VALUES(?,?,?,?,?)`,
		u.ID, in.ShoeID, in.Size, in.Phone, in.Comment)
	if err != nil {
		serverError(w, err)
		return
	}
	id, _ := res.LastInsertId()
	o, err := a.findOrder(id, u)
	if err != nil {
		serverError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, o)
}

func scanOrder(row scanner, viewer *User) (*Order, error) {
	var o Order
	var seenAdmin, seenClient int
	err := row.Scan(&o.ID, &o.UserID, &o.UserName, &o.ShoeID, &o.ShoeName, &o.ShoeBrand, &o.ShoeImage, &o.ShoePrice,
		&o.Size, &o.Phone, &o.Comment, &o.Status, &o.AdminComment, &seenAdmin, &seenClient, &o.CreatedAt, &o.UpdatedAt)
	if err != nil {
		return nil, err
	}
	if viewer.Role == "admin" {
		o.IsNew = seenAdmin == 0
	} else {
		o.IsNew = seenClient == 0
	}
	return &o, nil
}

func (a *App) findOrder(id int64, viewer *User) (*Order, error) {
	return scanOrder(a.DB.QueryRow(orderSelect+" WHERE o.id=?", id), viewer)
}

// GET /api/orders?status= — админ видит все заявки, клиент — только свои.
func (a *App) listOrders(w http.ResponseWriter, r *http.Request) {
	u := currentUser(r)
	where := []string{"1=1"}
	args := []any{}
	if u.Role != "admin" {
		where = append(where, "o.user_id=?")
		args = append(args, u.ID)
	}
	if st := r.URL.Query().Get("status"); st != "" {
		where = append(where, "o.status=?")
		args = append(args, st)
	}
	rows, err := a.DB.Query(orderSelect+" WHERE "+strings.Join(where, " AND ")+
		" ORDER BY (o.status='pending') DESC, o.id DESC", args...)
	if err != nil {
		serverError(w, err)
		return
	}
	defer rows.Close()
	list := []*Order{}
	for rows.Next() {
		o, err := scanOrder(rows, u)
		if err != nil {
			serverError(w, err)
			return
		}
		list = append(list, o)
	}
	writeJSON(w, http.StatusOK, list)
}

// PUT /api/orders/{id}/approve и /reject — решение администратора.
// Клиент получит уведомление об изменении статуса.
func (a *App) decideOrder(status string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id, ok := pathID(w, r)
		if !ok {
			return
		}
		var in struct {
			Comment string `json:"comment"`
		}
		if r.ContentLength > 0 && !decodeJSON(w, r, &in) {
			return
		}
		res, err := a.DB.Exec(`UPDATE orders SET status=?, admin_comment=?, seen_by_admin=1, seen_by_client=0,
			updated_at=datetime('now') WHERE id=? AND status='pending'`, status, strings.TrimSpace(in.Comment), id)
		if err != nil {
			serverError(w, err)
			return
		}
		if n, _ := res.RowsAffected(); n == 0 {
			writeError(w, http.StatusConflict, "Заявка не найдена или уже обработана")
			return
		}
		o, err := a.findOrder(id, currentUser(r))
		if err != nil {
			serverError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, o)
	}
}

// DELETE /api/orders/{id} — клиент отменяет свою заявку, пока она не обработана.
func (a *App) cancelOrder(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	res, err := a.DB.Exec(`DELETE FROM orders WHERE id=? AND user_id=? AND status='pending'`, id, currentUser(r).ID)
	if err != nil {
		serverError(w, err)
		return
	}
	if n, _ := res.RowsAffected(); n == 0 {
		writeError(w, http.StatusConflict, "Заявку нельзя отменить")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// GET /api/notifications — количество непросмотренных событий:
// для администратора — новые заявки клиентов, для клиента — ответы на его заявки.
func (a *App) notifications(w http.ResponseWriter, r *http.Request) {
	u := currentUser(r)
	var n int
	var err error
	if u.Role == "admin" {
		err = a.DB.QueryRow(`SELECT COUNT(*) FROM orders WHERE seen_by_admin=0`).Scan(&n)
	} else {
		err = a.DB.QueryRow(`SELECT COUNT(*) FROM orders WHERE user_id=? AND seen_by_client=0`, u.ID).Scan(&n)
	}
	if err != nil {
		serverError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]int{"unread": n})
}

// POST /api/notifications/read — отметить все уведомления как просмотренные.
func (a *App) readNotifications(w http.ResponseWriter, r *http.Request) {
	u := currentUser(r)
	var err error
	if u.Role == "admin" {
		_, err = a.DB.Exec(`UPDATE orders SET seen_by_admin=1 WHERE seen_by_admin=0`)
	} else {
		_, err = a.DB.Exec(`UPDATE orders SET seen_by_client=1 WHERE user_id=? AND seen_by_client=0`, u.ID)
	}
	if err != nil {
		serverError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
