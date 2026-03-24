// backend/internal/transport/http/handlers/middleware/metrics.go
package middleware

import (
	"net/http"
	"strconv"
	"time"

	"petio/backend/internal/metrics"

	"github.com/go-chi/chi/v5"
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
		endpoint := normalizeEndpoint(r)

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

// normalizeEndpoint uses chi's route pattern for accurate endpoint labeling.
func normalizeEndpoint(r *http.Request) string {
	rctx := chi.RouteContext(r.Context())
	if rctx != nil && rctx.RoutePattern() != "" {
		return rctx.RoutePattern()
	}
	return r.URL.Path
}
