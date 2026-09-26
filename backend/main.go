// Серверная часть веб-приложения «Каталог спортивной обуви».
// REST API на стандартной библиотеке net/http, данные хранятся в SQLite.
package main

import (
	"flag"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

func main() {
	addr := flag.String("addr", ":8080", "адрес HTTP-сервера")
	dbPath := flag.String("db", "shoes.db", "путь к файлу базы данных SQLite")
	webDir := flag.String("web", "../frontend/build/web", "каталог собранного Flutter Web (необязательно)")
	flag.Parse()

	db, err := OpenDB(*dbPath)
	if err != nil {
		log.Fatalf("не удалось открыть БД: %v", err)
	}
	defer db.Close()

	app := &App{DB: db}
	mux := http.NewServeMux()
	app.RegisterRoutes(mux)

	// Изображения обуви.
	mux.Handle("GET /images/", http.StripPrefix("/images/", http.FileServer(http.Dir("static/images"))))

	// Если Flutter Web уже собран, раздаём его с того же сервера.
	if st, err := os.Stat(*webDir); err == nil && st.IsDir() {
		mux.Handle("/", spaHandler(*webDir))
		log.Printf("Flutter Web раздаётся из %s", *webDir)
	}

	srv := &http.Server{
		Addr:              *addr,
		Handler:           logging(cors(mux)),
		ReadHeaderTimeout: 10 * time.Second,
	}
	log.Printf("Сервер запущен: http://localhost%s", *addr)
	log.Fatal(srv.ListenAndServe())
}

// spaHandler отдаёт статические файлы, а на неизвестные пути — index.html.
func spaHandler(dir string) http.Handler {
	fs := http.FileServer(http.Dir(dir))
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		p := filepath.Join(dir, filepath.Clean(r.URL.Path))
		if _, err := os.Stat(p); os.IsNotExist(err) {
			http.ServeFile(w, r, filepath.Join(dir, "index.html"))
			return
		}
		fs.ServeHTTP(w, r)
	})
}

// cors разрешает запросы из Flutter-приложения, запущенного на другом порту.
func cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

func logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		if len(r.URL.Path) >= 4 && r.URL.Path[:4] == "/api" {
			log.Printf("%s %s -> %d (%s)", r.Method, r.URL.RequestURI(), rec.status, time.Since(start).Round(time.Millisecond))
		}
	})
}
