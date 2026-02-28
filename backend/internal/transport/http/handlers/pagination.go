package handlers

import (
	"net/http"
	"strconv"
)

const defaultLimit = 20
const maxLimit = 100

// parseLimitOffset reads limit and offset from query (e.g. ?limit=20&offset=0).
// Default limit 20, max 100; offset must be >= 0.
func parseLimitOffset(r *http.Request) (limit, offset int) {
	limit = defaultLimit
	offset = 0
	if s := r.URL.Query().Get("limit"); s != "" {
		if n, err := strconv.Atoi(s); err == nil && n > 0 {
			limit = n
			if limit > maxLimit {
				limit = maxLimit
			}
		}
	}
	if s := r.URL.Query().Get("offset"); s != "" {
		if n, err := strconv.Atoi(s); err == nil && n >= 0 {
			offset = n
		}
	}
	return limit, offset
}
