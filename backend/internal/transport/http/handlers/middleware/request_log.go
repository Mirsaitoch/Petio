package middleware

import (
	"bytes"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"go.uber.org/zap"

	"petio/backend/internal/logger"
)

const maxBodyLog = 4096 // не логируем тела больше 4 КБ

// RequestLog логирует каждый запрос с trace_id, request body и response body.
func RequestLog(base *zap.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			reqID := chimiddleware.GetReqID(r.Context())
			if reqID == "" {
				reqID = "-"
			}

			reqLog := base.With(zap.String("trace_id", reqID))
			ctx := logger.ToCtx(r.Context(), reqLog)

			// ── Захват request body ──
			var reqBody string
			if r.Body != nil && r.ContentLength != 0 && isJSON(r.Header.Get("Content-Type")) {
				body, _ := io.ReadAll(io.LimitReader(r.Body, maxBodyLog+1))
				r.Body.Close()
				if len(body) > maxBodyLog {
					reqBody = string(body[:maxBodyLog]) + "...(truncated)"
				} else {
					reqBody = string(body)
				}
				reqBody = maskSensitive(reqBody)
				r.Body = io.NopCloser(bytes.NewReader(body))
			}

			// ── Захват response body ──
			ww := chimiddleware.NewWrapResponseWriter(w, r.ProtoMajor)
			var respBuf bytes.Buffer
			ww.Tee(&respBuf)

			next.ServeHTTP(ww, r.WithContext(ctx))

			// Не логируем служебные эндпоинты
			if strings.HasPrefix(r.URL.Path, "/metrics") || strings.HasPrefix(r.URL.Path, "/health") {
				return
			}

			userID := UserIDFromContext(r.Context())

			msg := r.Method + " " + r.URL.Path
			if rctx := chi.RouteContext(r.Context()); rctx != nil && rctx.RoutePattern() != "" {
				msg = r.Method + " " + rctx.RoutePattern()
			}

			fields := []zap.Field{
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
			if reqBody != "" {
				fields = append(fields, zap.String("req_body", reqBody))
			}

			respBody := respBuf.String()
			if len(respBody) > maxBodyLog {
				respBody = respBody[:maxBodyLog] + "...(truncated)"
			}
			if respBody != "" {
				fields = append(fields, zap.String("resp_body", respBody))
			}

			status := ww.Status()
			switch {
			case status >= 500:
				reqLog.Error(msg, fields...)
			case status >= 400:
				reqLog.Warn(msg, fields...)
			default:
				reqLog.Info(msg, fields...)
			}
		})
	}
}

func isJSON(contentType string) bool {
	return strings.Contains(contentType, "application/json")
}

// maskSensitive заменяет значения чувствительных полей на "***".
func maskSensitive(body string) string {
	for _, key := range []string{"password", "new_password", "refreshToken"} {
		body = maskField(body, key)
	}
	return body
}

func maskField(body, field string) string {
	needle := `"` + field + `":"`
	idx := strings.Index(body, needle)
	if idx == -1 {
		return body
	}
	start := idx + len(needle)
	end := strings.Index(body[start:], `"`)
	if end == -1 {
		return body
	}
	return body[:start] + "***" + body[start+end:]
}
