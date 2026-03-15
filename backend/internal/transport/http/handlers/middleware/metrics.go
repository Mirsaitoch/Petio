// backend/internal/transport/http/handlers/middleware/metrics.go
package middleware

import (
	"net/http"
	"strconv"
	"time"

	"petio/backend/internal/metrics"

	chimiddleware "github.com/go-chi/chi/v5/middleware"
)

// PrometheusMetrics собирает метрики по HTTP запросам
func PrometheusMetrics(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Оборачиваем ResponseWriter для получения статуса
		ww := chimiddleware.NewWrapResponseWriter(w, r.ProtoMajor)

		// Выполняем запрос
		next.ServeHTTP(ww, r)

		// Собираем метрики
		duration := time.Since(start).Seconds()
		status := strconv.Itoa(ww.Status())
		endpoint := normalizeEndpoint(r.URL.Path)

		metrics.HTTPRequestsTotal.WithLabelValues(
			r.Method,
			endpoint,
			status,
		).Inc()

		metrics.HTTPRequestDuration.WithLabelValues(
			r.Method,
			endpoint,
			status,
		).Observe(duration)

		metrics.HTTPResponseSize.WithLabelValues(
			r.Method,
			endpoint,
		).Observe(float64(ww.BytesWritten()))
	})
}

// normalizeEndpoint заменяет параметры пути на placeholders
// Например: /v1/chats/abc-123/messages -> /v1/chats/{id}/messages
func normalizeEndpoint(path string) string {
	// Простая нормализация для основных роутов
	// В продакшене лучше использовать chi.RoutePattern(r)
	switch {
	case len(path) > 10 && path[:10] == "/v1/chats/":
		if len(path) > 46 { // UUID length
			return "/v1/chats/{id}/messages"
		}
		return "/v1/chats/{id}"
	case len(path) > 9 && path[:9] == "/v1/pets/":
		return "/v1/pets/{id}"
	case len(path) > 10 && path[:10] == "/v1/posts/":
		return "/v1/posts/{id}"
	}
	return path
}
