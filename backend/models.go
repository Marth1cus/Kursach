package main

import (
	"sort"
	"strconv"
	"strings"
)

// User — пользователь системы (клиент или администратор).
type User struct {
	ID        int64  `json:"id"`
	Login     string `json:"login"`
	Name      string `json:"name"`
	Role      string `json:"role"`
	Blocked   bool   `json:"blocked"`
	CreatedAt string `json:"created_at"`
}

// Shoe — модель спортивной обуви в каталоге.
type Shoe struct {
	ID           int64    `json:"id"`
	Name         string   `json:"name"`
	Brand        string   `json:"brand"`
	Category     string   `json:"category"`
	Gender       string   `json:"gender"`
	Price        int      `json:"price"`
	OldPrice     int      `json:"old_price"`
	Color        string   `json:"color"`
	Sizes        []string `json:"sizes"`
	Material     string   `json:"material"`
	Surface      string   `json:"surface"`
	Weight       int      `json:"weight"`
	Description  string   `json:"description"`
	ImageURL     string   `json:"image_url"`
	InStock      bool     `json:"in_stock"`
	Deleted      bool     `json:"deleted"`
	DeletedAt    *string  `json:"deleted_at"`
	Rating       float64  `json:"rating"`
	ReviewsCount int      `json:"reviews_count"`
	IsFavorite   bool     `json:"is_favorite"`
	CreatedAt    string   `json:"created_at"`
	UpdatedAt    string   `json:"updated_at"`
}

// Review — отзыв пользователя о модели.
type Review struct {
	ID        int64  `json:"id"`
	ShoeID    int64  `json:"shoe_id"`
	UserID    int64  `json:"user_id"`
	UserName  string `json:"user_name"`
	Rating    int    `json:"rating"`
	Text      string `json:"text"`
	CreatedAt string `json:"created_at"`
}

// Order — заявка клиента на бронирование пары для примерки/покупки.
type Order struct {
	ID           int64  `json:"id"`
	UserID       int64  `json:"user_id"`
	UserName     string `json:"user_name"`
	ShoeID       int64  `json:"shoe_id"`
	ShoeName     string `json:"shoe_name"`
	ShoeBrand    string `json:"shoe_brand"`
	ShoeImage    string `json:"shoe_image"`
	ShoePrice    int    `json:"shoe_price"`
	Size         string `json:"size"`
	Phone        string `json:"phone"`
	Comment      string `json:"comment"`
	Status       string `json:"status"`
	AdminComment string `json:"admin_comment"`
	IsNew        bool   `json:"is_new"`
	CreatedAt    string `json:"created_at"`
	UpdatedAt    string `json:"updated_at"`
}

var (
	allowedCategories = map[string]bool{
		"running": true, "basketball": true, "football": true, "training": true,
		"tennis": true, "trail": true, "lifestyle": true, "volleyball": true,
	}
	allowedGenders = map[string]bool{"men": true, "women": true, "unisex": true}
)

func joinSizes(s []string) string { return strings.Join(normalizeSizes(s), ",") }

func splitSizes(s string) []string {
	if s == "" {
		return []string{}
	}
	return strings.Split(s, ",")
}

// normalizeSizes убирает пустые значения и дубликаты, сортирует по возрастанию.
func normalizeSizes(in []string) []string {
	seen := map[string]bool{}
	out := make([]string, 0, len(in))
	for _, s := range in {
		s = strings.TrimSpace(strings.ReplaceAll(s, ",", "."))
		if s == "" || seen[s] {
			continue
		}
		seen[s] = true
		out = append(out, s)
	}
	sort.Slice(out, func(i, j int) bool {
		a, _ := strconv.ParseFloat(out[i], 64)
		b, _ := strconv.ParseFloat(out[j], 64)
		return a < b
	})
	return out
}
