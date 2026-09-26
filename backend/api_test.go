package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
)

// newTestServer поднимает API на временной БД с начальными данными.
func newTestServer(t *testing.T) *httptest.Server {
	t.Helper()
	db, err := OpenDB(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	mux := http.NewServeMux()
	(&App{DB: db}).RegisterRoutes(mux)
	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)
	return srv
}

func call(t *testing.T, srv *httptest.Server, method, path, token string, body any, out any) int {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		json.NewEncoder(&buf).Encode(body)
	}
	req, _ := http.NewRequest(method, srv.URL+path, &buf)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if out != nil {
		json.NewDecoder(resp.Body).Decode(out)
	}
	return resp.StatusCode
}

func loginAs(t *testing.T, srv *httptest.Server, login, pass string) (string, User) {
	t.Helper()
	var res struct {
		Token string `json:"token"`
		User  User   `json:"user"`
	}
	if code := call(t, srv, "POST", "/api/auth/login", "", map[string]string{"login": login, "password": pass}, &res); code != 200 {
		t.Fatalf("вход %s: код %d", login, code)
	}
	return res.Token, res.User
}

func TestRoleIsDetectedByServer(t *testing.T) {
	srv := newTestServer(t)
	_, admin := loginAs(t, srv, "admin", "admin123")
	_, client := loginAs(t, srv, "client", "client123")
	if admin.Role != "admin" || client.Role != "client" {
		t.Fatalf("роли определены неверно: %s, %s", admin.Role, client.Role)
	}
	if code := call(t, srv, "POST", "/api/auth/login", "", map[string]string{"login": "admin", "password": "bad"}, nil); code != 401 {
		t.Fatalf("неверный пароль: ожидался 401, получен %d", code)
	}
}

func TestPaginationBy5(t *testing.T) {
	srv := newTestServer(t)
	token, _ := loginAs(t, srv, "client", "client123")
	var page struct {
		Items []Shoe `json:"items"`
		Total int    `json:"total"`
	}
	call(t, srv, "GET", "/api/shoes?limit=5&offset=35", token, nil, &page)
	if page.Total != 40 || len(page.Items) != 5 {
		t.Fatalf("ожидалось 40 моделей и страница из 5, получено %d и %d", page.Total, len(page.Items))
	}
}

func TestClientCannotEditCatalog(t *testing.T) {
	srv := newTestServer(t)
	token, _ := loginAs(t, srv, "client", "client123")
	if code := call(t, srv, "DELETE", "/api/shoes/1", token, nil, nil); code != 403 {
		t.Fatalf("клиент удалил модель: код %d", code)
	}
}

func TestTrashAndRestore(t *testing.T) {
	srv := newTestServer(t)
	token, _ := loginAs(t, srv, "admin", "admin123")
	if code := call(t, srv, "DELETE", "/api/shoes/3", token, nil, nil); code != 204 {
		t.Fatalf("удаление: %d", code)
	}
	var trash struct{ Total int }
	call(t, srv, "GET", "/api/shoes?deleted=1", token, nil, &trash)
	if trash.Total != 1 {
		t.Fatalf("в корзине %d моделей", trash.Total)
	}
	if code := call(t, srv, "PUT", "/api/shoes/3/restore", token, nil, nil); code != 204 {
		t.Fatalf("восстановление: %d", code)
	}
}

func TestOrderNotifiesAdmin(t *testing.T) {
	srv := newTestServer(t)
	admin, _ := loginAs(t, srv, "admin", "admin123")
	client, _ := loginAs(t, srv, "client", "client123")
	order := map[string]any{"shoe_id": 1, "size": "42", "phone": "+7 999 000-00-00"}
	if code := call(t, srv, "POST", "/api/orders", client, order, nil); code != 201 {
		t.Fatalf("создание заявки: %d", code)
	}
	var n struct{ Unread int }
	call(t, srv, "GET", "/api/notifications", admin, nil, &n)
	if n.Unread != 1 {
		t.Fatalf("у администратора %d уведомлений, ожидалось 1", n.Unread)
	}
	call(t, srv, "PUT", "/api/orders/1/approve", admin, nil, nil)
	call(t, srv, "GET", "/api/notifications", client, nil, &n)
	if n.Unread != 1 {
		t.Fatalf("клиент не получил уведомление об ответе")
	}
}

func TestBlockedUserCannotLogin(t *testing.T) {
	srv := newTestServer(t)
	admin, _ := loginAs(t, srv, "admin", "admin123")
	client, u := loginAs(t, srv, "client", "client123")
	call(t, srv, "PUT", "/api/users/"+itoa(u.ID)+"/block", admin, nil, nil)
	if code := call(t, srv, "GET", "/api/shoes", client, nil, nil); code != 401 {
		t.Fatalf("сессия заблокированного не завершена: %d", code)
	}
	if code := call(t, srv, "POST", "/api/auth/login", "", map[string]string{"login": "client", "password": "client123"}, nil); code != 403 {
		t.Fatalf("заблокированный вошёл: %d", code)
	}
}

func itoa(v int64) string { b, _ := json.Marshal(v); return string(b) }
