package middleware

import (
	"net/http"
	"time"

	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"go.uber.org/zap"

	"petio/backend/internal/logger"
)

// RequestLog логирует каждый запрос с request_id и user_id для трассировки.
// Обогащённый логгер кладётся в контекст — все хендлеры используют logger.FromCtx(ctx).
func RequestLog(base *zap.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			reqID := chimiddleware.GetReqID(r.Context())
			if reqID == "" {
				reqID = "-"
			}

			// Кладём логгер с request_id в контекст ДО вызова next,
			// чтобы хендлеры могли им пользоваться.
			reqLog := base.With(zap.String("request_id", reqID))
			ctx := logger.ToCtx(r.Context(), reqLog)

			ww := chimiddleware.NewWrapResponseWriter(w, r.ProtoMajor)
			next.ServeHTTP(ww, r.WithContext(ctx))

			// После ответа — дописываем user_id (из JWT middleware) и логируем.
			userID := UserIDFromContext(r.Context())

			fields := []zap.Field{
				zap.String("method", r.Method),
				zap.String("path", r.URL.Path),
				zap.Int("status", ww.Status()),
				zap.Int64("duration_ms", time.Since(start).Milliseconds()),
				zap.Int("bytes", ww.BytesWritten()),
			}
			if userID != "" {
				fields = append(fields, zap.String("user_id", userID))
			}
			if r.URL.RawQuery != "" {
				fields = append(fields, zap.String("query", r.URL.RawQuery))
			}

			status := ww.Status()
			switch {
			case status >= 500:
				reqLog.Error("request", fields...)
			case status >= 400:
				reqLog.Warn("request", fields...)
			default:
				reqLog.Info("request", fields...)
			}
		})
	}
}
