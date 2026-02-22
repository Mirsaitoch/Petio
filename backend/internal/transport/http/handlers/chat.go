package handlers

import (
	"context"
	"encoding/json"
	"net/http"

	"petio/backend/internal/transport/http/handlers/middleware"
)

type ChatSender interface {
	Send(ctx context.Context, text string) (string, error)
}

type ChatHandler struct {
	sender ChatSender
}

func NewChatHandler(sender ChatSender) *ChatHandler {
	return &ChatHandler{sender: sender}
}

// Send godoc
// @Summary      Отправить сообщение в чат
// @Tags         chat
// @Accept       json
// @Produce      json
// @Param        body body object true "text"
// @Success      200 {object} map[string]string "reply"
// @Router       /v1/chat/send [post]
// @Security     BearerAuth
func (h *ChatHandler) Send(w http.ResponseWriter, r *http.Request) {
	_ = middleware.UserIDFromContext(r.Context())
	var body struct {
		Text string `json:"text"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	reply, err := h.sender.Send(r.Context(), body.Text)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusOK, map[string]string{"reply": reply})
}
