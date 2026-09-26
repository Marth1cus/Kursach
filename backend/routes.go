package main

import "net/http"

// RegisterRoutes описывает все эндпоинты REST API.
func (a *App) RegisterRoutes(mux *http.ServeMux) {
	// Авторизация
	mux.HandleFunc("POST /api/auth/register", a.register)
	mux.HandleFunc("POST /api/auth/login", a.login)
	mux.HandleFunc("GET /api/auth/me", a.auth(a.me))
	mux.HandleFunc("POST /api/auth/logout", a.auth(a.logout))

	// Каталог
	mux.HandleFunc("GET /api/meta", a.auth(a.meta))
	mux.HandleFunc("GET /api/shoes", a.auth(a.listShoes))
	mux.HandleFunc("GET /api/shoes/{id}", a.auth(a.getShoe))
	mux.HandleFunc("POST /api/shoes", a.admin(a.createShoe))
	mux.HandleFunc("PUT /api/shoes/{id}", a.admin(a.updateShoe))
	mux.HandleFunc("DELETE /api/shoes/{id}", a.admin(a.deleteShoe))
	mux.HandleFunc("PUT /api/shoes/{id}/restore", a.admin(a.restoreShoe))
	mux.HandleFunc("DELETE /api/shoes/{id}/purge", a.admin(a.purgeShoe))

	// Избранное
	mux.HandleFunc("POST /api/favorites/{id}", a.auth(a.addFavorite))
	mux.HandleFunc("DELETE /api/favorites/{id}", a.auth(a.removeFavorite))

	// Отзывы
	mux.HandleFunc("GET /api/shoes/{id}/reviews", a.auth(a.listReviews))
	mux.HandleFunc("POST /api/shoes/{id}/reviews", a.auth(a.addReview))
	mux.HandleFunc("DELETE /api/reviews/{id}", a.auth(a.deleteReview))

	// Заявки на бронирование и уведомления
	mux.HandleFunc("GET /api/orders", a.auth(a.listOrders))
	mux.HandleFunc("POST /api/orders", a.auth(a.createOrder))
	mux.HandleFunc("DELETE /api/orders/{id}", a.auth(a.cancelOrder))
	mux.HandleFunc("PUT /api/orders/{id}/approve", a.admin(a.decideOrder("approved")))
	mux.HandleFunc("PUT /api/orders/{id}/reject", a.admin(a.decideOrder("rejected")))
	mux.HandleFunc("GET /api/notifications", a.auth(a.notifications))
	mux.HandleFunc("POST /api/notifications/read", a.auth(a.readNotifications))

	// Администрирование
	mux.HandleFunc("GET /api/users", a.admin(a.listUsers))
	mux.HandleFunc("PUT /api/users/{id}/block", a.admin(a.setBlocked(true)))
	mux.HandleFunc("PUT /api/users/{id}/unblock", a.admin(a.setBlocked(false)))
	mux.HandleFunc("GET /api/stats", a.admin(a.stats))

	mux.HandleFunc("/api/", func(w http.ResponseWriter, r *http.Request) {
		writeError(w, http.StatusNotFound, "Метод API не найден")
	})
}
