package middleware

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	chimiddleware "github.com/go-chi/chi/v5/middleware"
)

type requestLogLine struct {
	RequestID  string `json:"request_id"`
	Method     string `json:"method"`
	Path       string `json:"path"`
	Status     int    `json:"status"`
	DurationMs int64  `json:"duration_ms"`
}

// RequestLog logs each request as one JSON line with request_id for tracing.
func RequestLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		ww := chimiddleware.NewWrapResponseWriter(w, r.ProtoMajor)
		next.ServeHTTP(ww, r)
		reqID := chimiddleware.GetReqID(r.Context())
		if reqID == "" {
			reqID = "-"
		}
		line := requestLogLine{
			RequestID:  reqID,
			Method:     r.Method,
			Path:       r.URL.Path,
			Status:     ww.Status(),
			DurationMs: time.Since(start).Milliseconds(),
		}
		b, _ := json.Marshal(line)
		log.Println(string(b))
	})
}
