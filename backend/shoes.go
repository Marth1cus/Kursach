package main

import (
	"database/sql"
	"net/http"
	"strconv"
	"strings"
	"unicode/utf8"
)

// Базовый SELECT с рейтингом, количеством отзывов и признаком избранного
// для текущего пользователя (параметр ? — id пользователя).
const shoeSelect = `
SELECT s.id,s.name,s.brand,s.category,s.gender,s.price,s.old_price,s.color,s.sizes,
       s.material,s.surface,s.weight,s.description,s.image_url,s.in_stock,s.deleted,s.deleted_at,
       COALESCE((SELECT ROUND(AVG(rating),1) FROM reviews WHERE shoe_id=s.id),0),
       (SELECT COUNT(*) FROM reviews WHERE shoe_id=s.id),
       EXISTS(SELECT 1 FROM favorites f WHERE f.shoe_id=s.id AND f.user_id=?),
       s.created_at,s.updated_at
FROM shoes s`

type scanner interface{ Scan(dest ...any) error }

func scanShoe(row scanner) (*Shoe, error) {
	var s Shoe
	var sizes string
	var inStock, deleted, fav int
	err := row.Scan(&s.ID, &s.Name, &s.Brand, &s.Category, &s.Gender, &s.Price, &s.OldPrice, &s.Color, &sizes,
		&s.Material, &s.Surface, &s.Weight, &s.Description, &s.ImageURL, &inStock, &deleted, &s.DeletedAt,
		&s.Rating, &s.ReviewsCount, &fav, &s.CreatedAt, &s.UpdatedAt)
	if err != nil {
		return nil, err
	}
	s.Sizes = splitSizes(sizes)
	s.InStock, s.Deleted, s.IsFavorite = inStock == 1, deleted == 1, fav == 1
	return &s, nil
}

// GET /api/shoes — список моделей с фильтрами, сортировкой и пагинацией.
//
// Параметры: limit, offset, q, category, brands (через запятую), gender,
// min_price, max_price, size, in_stock=1, favorites=1, deleted=1 (корзина, admin),
// sort = new | price_asc | price_desc | rating | name.
func (a *App) listShoes(w http.ResponseWriter, r *http.Request) {
	u := currentUser(r)
	q := r.URL.Query()

	limit, _ := strconv.Atoi(q.Get("limit"))
	offset, _ := strconv.Atoi(q.Get("offset"))
	if limit <= 0 || limit > 100 {
		limit = 5
	}
	if offset < 0 {
		offset = 0
	}

	where := []string{"s.deleted = ?"}
	args := []any{0}
	if q.Get("deleted") == "1" {
		if u.Role != "admin" {
			writeError(w, http.StatusForbidden, "Корзина доступна только администратору")
			return
		}
		args[0] = 1
	}
	if v := strings.TrimSpace(q.Get("q")); v != "" {
		// LOWER в SQLite не работает с кириллицей, поэтому ищем по двум вариантам.
		where = append(where, "(s.name LIKE ? OR s.brand LIKE ? OR s.color LIKE ? OR s.color LIKE ?)")
		like := "%" + v + "%"
		args = append(args, like, like, "%"+strings.ToLower(v)+"%", "%"+capitalize(v)+"%")
	}
	if v := q.Get("category"); v != "" {
		where = append(where, "s.category = ?")
		args = append(args, v)
	}
	if v := q.Get("gender"); v != "" {
		// Унисекс-модели подходят и мужчинам, и женщинам.
		where = append(where, "(s.gender = ? OR s.gender = 'unisex')")
		args = append(args, v)
	}
	if v := q.Get("brands"); v != "" {
		brands := strings.Split(v, ",")
		where = append(where, "s.brand IN (?"+strings.Repeat(",?", len(brands)-1)+")")
		for _, b := range brands {
			args = append(args, b)
		}
	}
	if v, err := strconv.Atoi(q.Get("min_price")); err == nil {
		where = append(where, "s.price >= ?")
		args = append(args, v)
	}
	if v, err := strconv.Atoi(q.Get("max_price")); err == nil {
		where = append(where, "s.price <= ?")
		args = append(args, v)
	}
	if v := q.Get("size"); v != "" {
		where = append(where, "(',' || s.sizes || ',') LIKE ?")
		args = append(args, "%,"+v+",%")
	}
	if q.Get("in_stock") == "1" {
		where = append(where, "s.in_stock = 1")
	}
	if q.Get("favorites") == "1" {
		where = append(where, "EXISTS(SELECT 1 FROM favorites f2 WHERE f2.shoe_id=s.id AND f2.user_id=?)")
		args = append(args, u.ID)
	}
	if q.Get("sale") == "1" {
		where = append(where, "s.old_price > s.price")
	}

	order := map[string]string{
		"new":        "s.id DESC",
		"price_asc":  "s.price ASC, s.id",
		"price_desc": "s.price DESC, s.id",
		"rating":     "COALESCE((SELECT AVG(rating) FROM reviews WHERE shoe_id=s.id),0) DESC, s.id",
		"name":       "s.brand, s.name",
	}[q.Get("sort")]
	if order == "" {
		order = "s.id ASC"
	}
	if q.Get("deleted") == "1" {
		order = "s.deleted_at DESC"
	}

	cond := " WHERE " + strings.Join(where, " AND ")
	var total int
	if err := a.DB.QueryRow("SELECT COUNT(*) FROM shoes s"+cond, args...).Scan(&total); err != nil {
		serverError(w, err)
		return
	}

	fullArgs := append([]any{u.ID}, args...)
	fullArgs = append(fullArgs, limit, offset)
	rows, err := a.DB.Query(shoeSelect+cond+" ORDER BY "+order+" LIMIT ? OFFSET ?", fullArgs...)
	if err != nil {
		serverError(w, err)
		return
	}
	defer rows.Close()
	items := []*Shoe{}
	for rows.Next() {
		s, err := scanShoe(rows)
		if err != nil {
			serverError(w, err)
			return
		}
		items = append(items, s)
	}
	if err := rows.Err(); err != nil {
		serverError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items, "total": total, "limit": limit, "offset": offset})
}

func capitalize(s string) string {
	r, n := utf8.DecodeRuneInString(s)
	return strings.ToUpper(string(r)) + strings.ToLower(s[n:])
}

func (a *App) findShoe(id, userID int64) (*Shoe, error) {
	return scanShoe(a.DB.QueryRow(shoeSelect+" WHERE s.id=?", userID, id))
}

// GET /api/shoes/{id}
func (a *App) getShoe(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	u := currentUser(r)
	s, err := a.findShoe(id, u.ID)
	if isNotFound(err) || (err == nil && s.Deleted && u.Role != "admin") {
		writeError(w, http.StatusNotFound, "Модель не найдена")
		return
	}
	if err != nil {
		serverError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, s)
}

type shoeInput struct {
	Name        string   `json:"name"`
	Brand       string   `json:"brand"`
	Category    string   `json:"category"`
	Gender      string   `json:"gender"`
	Price       int      `json:"price"`
	OldPrice    int      `json:"old_price"`
	Color       string   `json:"color"`
	Sizes       []string `json:"sizes"`
	Material    string   `json:"material"`
	Surface     string   `json:"surface"`
	Weight      int      `json:"weight"`
	Description string   `json:"description"`
	ImageURL    string   `json:"image_url"`
	InStock     bool     `json:"in_stock"`
}

// validate проверяет данные модели и возвращает текст ошибки.
func (in *shoeInput) validate() string {
	in.Name = strings.TrimSpace(in.Name)
	in.Brand = strings.TrimSpace(in.Brand)
	in.Sizes = normalizeSizes(in.Sizes)
	switch {
	case utf8.RuneCountInString(in.Name) < 2 || utf8.RuneCountInString(in.Name) > 100:
		return "Название должно содержать от 2 до 100 символов"
	case in.Brand == "":
		return "Укажите бренд"
	case !allowedCategories[in.Category]:
		return "Некорректная категория"
	case !allowedGenders[in.Gender]:
		return "Некорректное значение пола"
	case in.Price <= 0 || in.Price > 1_000_000:
		return "Цена должна быть от 1 до 1 000 000 ₽"
	case in.OldPrice < 0:
		return "Старая цена не может быть отрицательной"
	case in.OldPrice != 0 && in.OldPrice <= in.Price:
		return "Старая цена должна быть больше текущей"
	case len(in.Sizes) == 0:
		return "Выберите хотя бы один размер"
	case in.Weight < 0 || in.Weight > 3000:
		return "Вес должен быть от 0 до 3000 г"
	case utf8.RuneCountInString(in.Description) > 2000:
		return "Описание не должно превышать 2000 символов"
	}
	for _, s := range in.Sizes {
		if v, err := strconv.ParseFloat(s, 64); err != nil || v < 15 || v > 55 {
			return "Некорректный размер: " + s
		}
	}
	return ""
}

// POST /api/shoes — добавление модели (admin).
func (a *App) createShoe(w http.ResponseWriter, r *http.Request) {
	var in shoeInput
	if !decodeJSON(w, r, &in) {
		return
	}
	if msg := in.validate(); msg != "" {
		writeError(w, http.StatusBadRequest, msg)
		return
	}
	res, err := a.DB.Exec(`INSERT INTO shoes(name,brand,category,gender,price,old_price,color,sizes,material,surface,weight,description,image_url,in_stock)
		VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
		in.Name, in.Brand, in.Category, in.Gender, in.Price, in.OldPrice, in.Color, strings.Join(in.Sizes, ","),
		in.Material, in.Surface, in.Weight, in.Description, in.ImageURL, boolToInt(in.InStock))
	if err != nil {
		serverError(w, err)
		return
	}
	id, _ := res.LastInsertId()
	s, err := a.findShoe(id, currentUser(r).ID)
	if err != nil {
		serverError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, s)
}

// PUT /api/shoes/{id} — редактирование модели (admin).
func (a *App) updateShoe(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var in shoeInput
	if !decodeJSON(w, r, &in) {
		return
	}
	if msg := in.validate(); msg != "" {
		writeError(w, http.StatusBadRequest, msg)
		return
	}
	res, err := a.DB.Exec(`UPDATE shoes SET name=?,brand=?,category=?,gender=?,price=?,old_price=?,color=?,sizes=?,
		material=?,surface=?,weight=?,description=?,image_url=?,in_stock=?,updated_at=datetime('now') WHERE id=?`,
		in.Name, in.Brand, in.Category, in.Gender, in.Price, in.OldPrice, in.Color, strings.Join(in.Sizes, ","),
		in.Material, in.Surface, in.Weight, in.Description, in.ImageURL, boolToInt(in.InStock), id)
	if err != nil {
		serverError(w, err)
		return
	}
	if n, _ := res.RowsAffected(); n == 0 {
		writeError(w, http.StatusNotFound, "Модель не найдена")
		return
	}
	s, err := a.findShoe(id, currentUser(r).ID)
	if err != nil {
		serverError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, s)
}

// setDeleted перемещает модель в корзину или восстанавливает её.
func (a *App) setDeleted(w http.ResponseWriter, r *http.Request, deleted bool) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	var res sql.Result
	var err error
	if deleted {
		res, err = a.DB.Exec(`UPDATE shoes SET deleted=1, deleted_at=datetime('now') WHERE id=? AND deleted=0`, id)
	} else {
		res, err = a.DB.Exec(`UPDATE shoes SET deleted=0, deleted_at=NULL WHERE id=? AND deleted=1`, id)
	}
	if err != nil {
		serverError(w, err)
		return
	}
	if n, _ := res.RowsAffected(); n == 0 {
		writeError(w, http.StatusNotFound, "Модель не найдена")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// DELETE /api/shoes/{id} — мягкое удаление (в корзину).
func (a *App) deleteShoe(w http.ResponseWriter, r *http.Request) { a.setDeleted(w, r, true) }

// PUT /api/shoes/{id}/restore — восстановление из корзины.
func (a *App) restoreShoe(w http.ResponseWriter, r *http.Request) { a.setDeleted(w, r, false) }

// DELETE /api/shoes/{id}/purge — окончательное удаление из корзины.
func (a *App) purgeShoe(w http.ResponseWriter, r *http.Request) {
	id, ok := pathID(w, r)
	if !ok {
		return
	}
	res, err := a.DB.Exec(`DELETE FROM shoes WHERE id=? AND deleted=1`, id)
	if err != nil {
		serverError(w, err)
		return
	}
	if n, _ := res.RowsAffected(); n == 0 {
		writeError(w, http.StatusNotFound, "Модель не найдена в корзине")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// GET /api/meta — справочники для фильтров: бренды, размеры, диапазон цен.
func (a *App) meta(w http.ResponseWriter, r *http.Request) {
	brands := []string{}
	rows, err := a.DB.Query(`SELECT DISTINCT brand FROM shoes WHERE deleted=0 ORDER BY brand`)
	if err != nil {
		serverError(w, err)
		return
	}
	for rows.Next() {
		var b string
		if err := rows.Scan(&b); err == nil {
			brands = append(brands, b)
		}
	}
	rows.Close()

	var sizeRows []string
	rows, err = a.DB.Query(`SELECT sizes FROM shoes WHERE deleted=0`)
	if err != nil {
		serverError(w, err)
		return
	}
	for rows.Next() {
		var s string
		if err := rows.Scan(&s); err == nil {
			sizeRows = append(sizeRows, splitSizes(s)...)
		}
	}
	rows.Close()

	var minP, maxP int
	if err := a.DB.QueryRow(`SELECT COALESCE(MIN(price),0), COALESCE(MAX(price),0) FROM shoes WHERE deleted=0`).Scan(&minP, &maxP); err != nil {
		serverError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"brands": brands, "sizes": normalizeSizes(sizeRows), "min_price": minP, "max_price": maxP,
	})
}
