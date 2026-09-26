package main

import (
	"database/sql"
	"fmt"

	"golang.org/x/crypto/bcrypt"
	_ "modernc.org/sqlite"
)

const schema = `
CREATE TABLE IF NOT EXISTS users (
	id            INTEGER PRIMARY KEY AUTOINCREMENT,
	login         TEXT    NOT NULL UNIQUE,
	password_hash TEXT    NOT NULL,
	name          TEXT    NOT NULL,
	role          TEXT    NOT NULL CHECK (role IN ('client','admin')),
	blocked       INTEGER NOT NULL DEFAULT 0,
	created_at    TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS sessions (
	token      TEXT PRIMARY KEY,
	user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	created_at TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS shoes (
	id          INTEGER PRIMARY KEY AUTOINCREMENT,
	name        TEXT    NOT NULL,
	brand       TEXT    NOT NULL,
	category    TEXT    NOT NULL,
	gender      TEXT    NOT NULL CHECK (gender IN ('men','women','unisex')),
	price       INTEGER NOT NULL CHECK (price >= 0),
	old_price   INTEGER NOT NULL DEFAULT 0,
	color       TEXT    NOT NULL DEFAULT '',
	sizes       TEXT    NOT NULL DEFAULT '',
	material    TEXT    NOT NULL DEFAULT '',
	surface     TEXT    NOT NULL DEFAULT '',
	weight      INTEGER NOT NULL DEFAULT 0,
	description TEXT    NOT NULL DEFAULT '',
	image_url   TEXT    NOT NULL DEFAULT '',
	in_stock    INTEGER NOT NULL DEFAULT 1,
	deleted     INTEGER NOT NULL DEFAULT 0,
	deleted_at  TEXT,
	created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
	updated_at  TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS favorites (
	user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	shoe_id    INTEGER NOT NULL REFERENCES shoes(id) ON DELETE CASCADE,
	created_at TEXT    NOT NULL DEFAULT (datetime('now')),
	PRIMARY KEY (user_id, shoe_id)
);

CREATE TABLE IF NOT EXISTS reviews (
	id         INTEGER PRIMARY KEY AUTOINCREMENT,
	shoe_id    INTEGER NOT NULL REFERENCES shoes(id) ON DELETE CASCADE,
	user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	rating     INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
	text       TEXT    NOT NULL DEFAULT '',
	created_at TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS orders (
	id             INTEGER PRIMARY KEY AUTOINCREMENT,
	user_id        INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	shoe_id        INTEGER NOT NULL REFERENCES shoes(id) ON DELETE CASCADE,
	size           TEXT    NOT NULL,
	phone          TEXT    NOT NULL,
	comment        TEXT    NOT NULL DEFAULT '',
	status         TEXT    NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
	admin_comment  TEXT    NOT NULL DEFAULT '',
	seen_by_admin  INTEGER NOT NULL DEFAULT 0,
	seen_by_client INTEGER NOT NULL DEFAULT 1,
	created_at     TEXT    NOT NULL DEFAULT (datetime('now')),
	updated_at     TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_shoes_deleted ON shoes(deleted);
CREATE INDEX IF NOT EXISTS idx_reviews_shoe  ON reviews(shoe_id);
CREATE INDEX IF NOT EXISTS idx_orders_user   ON orders(user_id);
`

// OpenDB открывает (или создаёт) файл БД, применяет схему и заполняет
// начальными данными, если таблицы пустые.
func OpenDB(path string) (*sql.DB, error) {
	db, err := sql.Open("sqlite", path+"?_pragma=foreign_keys(1)&_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)")
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	if _, err := db.Exec(schema); err != nil {
		return nil, fmt.Errorf("применение схемы: %w", err)
	}
	if err := seed(db); err != nil {
		return nil, fmt.Errorf("заполнение данными: %w", err)
	}
	return db, nil
}

func hashPassword(p string) (string, error) {
	h, err := bcrypt.GenerateFromPassword([]byte(p), bcrypt.DefaultCost)
	return string(h), err
}

func seed(db *sql.DB) error {
	var n int
	if err := db.QueryRow(`SELECT COUNT(*) FROM users`).Scan(&n); err != nil {
		return err
	}
	if n == 0 {
		users := []struct{ login, pass, name, role string }{
			{"admin", "admin123", "Администратор", "admin"},
			{"client", "client123", "Иван Петров", "client"},
			{"anna", "anna123", "Анна Смирнова", "client"},
			{"sergey", "sergey123", "Сергей Козлов", "client"},
		}
		for _, u := range users {
			h, err := hashPassword(u.pass)
			if err != nil {
				return err
			}
			if _, err := db.Exec(`INSERT INTO users(login,password_hash,name,role) VALUES(?,?,?,?)`,
				u.login, h, u.name, u.role); err != nil {
				return err
			}
		}
	}

	if err := db.QueryRow(`SELECT COUNT(*) FROM shoes`).Scan(&n); err != nil {
		return err
	}
	if n > 0 {
		return nil
	}
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	for i, s := range seedShoes {
		stock := 1
		if !s.InStock {
			stock = 0
		}
		_, err := tx.Exec(`INSERT INTO shoes(name,brand,category,gender,price,old_price,color,sizes,material,surface,weight,description,image_url,in_stock)
			VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
			s.Name, s.Brand, s.Category, s.Gender, s.Price, s.OldPrice, s.Color, joinSizes(s.Sizes),
			s.Material, s.Surface, s.Weight, s.Description, fmt.Sprintf("/images/shoe_%02d.png", i+1), stock)
		if err != nil {
			return err
		}
	}
	// Несколько стартовых отзывов, чтобы у моделей был рейтинг.
	for _, r := range seedReviews {
		if _, err := tx.Exec(`INSERT INTO reviews(shoe_id,user_id,rating,text) VALUES(?,?,?,?)`,
			r.shoe, r.user, r.rating, r.text); err != nil {
			return err
		}
	}
	return tx.Commit()
}
