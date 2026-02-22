package handlers

import (
	"encoding/json"
	"net/http"
)

func jsonResponse(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if v != nil {
		_ = json.NewEncoder(w).Encode(v)
	}
}

func jsonError(w http.ResponseWriter, status int, errMsg string) {
	jsonResponse(w, status, map[string]string{"error": errMsg})
}
