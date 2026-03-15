// backend/internal/transport/http/handlers/chat.go
package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"petio/backend/internal/service"
	"petio/backend/internal/transport/http/handlers/middleware"
)

type ChatHandler struct {
	service *service.ChatService
}

func NewChatHandler(service *service.ChatService) *ChatHandler {
	return &ChatHandler{service: service}
}

// CreateChat godoc
// @Summary      Создать новый чат
// @Tags         chat
// @Accept       json
// @Produce      json
// @Param        body body object false "title (optional)"
// @Success      201 {object} domain.Chat
// @Router       /v1/chats [post]
// @Security     BearerAuth
func (h *ChatHandler) CreateChat(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var body struct {
		Title string `json:"title"`
	}
	_ = json.NewDecoder(r.Body).Decode(&body)

	chat, err := h.service.CreateChat(r.Context(), userID, body.Title)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResponse(w, http.StatusCreated, chat)
}

// ListChats godoc
// @Summary      Список всех чатов пользователя
// @Tags         chat
// @Produce      json
// @Param        limit query int false "Limit (default 20)"
// @Param        offset query int false "Offset"
// @Success      200 {array} domain.Chat
// @Router       /v1/chats [get]
// @Security     BearerAuth
func (h *ChatHandler) ListChats(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	chats, err := h.service.ListChats(r.Context(), userID, limit, offset)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, chats)
}

// GetChat godoc
// @Summary      Получить чат по ID
// @Tags         chat
// @Produce      json
// @Param        id path string true "Chat ID"
// @Success      200 {object} domain.Chat
// @Router       /v1/chats/{id} [get]
// @Security     BearerAuth
func (h *ChatHandler) GetChat(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	chatID := chi.URLParam(r, "id")
	if chatID == "" {
		jsonError(w, http.StatusBadRequest, "chat id required")
		return
	}

	chat, err := h.service.GetChat(r.Context(), chatID, userID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if chat == nil {
		jsonError(w, http.StatusNotFound, "chat not found")
		return
	}

	jsonResponse(w, http.StatusOK, chat)
}

// UpdateChatTitle godoc
// @Summary      Обновить название чата
// @Tags         chat
// @Accept       json
// @Param        id path string true "Chat ID"
// @Param        body body object true "title"
// @Success      200
// @Router       /v1/chats/{id} [patch]
// @Security     BearerAuth
func (h *ChatHandler) UpdateChatTitle(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	chatID := chi.URLParam(r, "id")
	var body struct {
		Title string `json:"title"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}

	if err := h.service.UpdateChatTitle(r.Context(), chatID, userID, body.Title); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	w.WriteHeader(http.StatusOK)
}

// DeleteChat godoc
// @Summary      Удалить чат
// @Tags         chat
// @Param        id path string true "Chat ID"
// @Success      204
// @Router       /v1/chats/{id} [delete]
// @Security     BearerAuth
func (h *ChatHandler) DeleteChat(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	chatID := chi.URLParam(r, "id")
	if err := h.service.DeleteChat(r.Context(), chatID, userID); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// GetMessages godoc
// @Summary      Получить историю сообщений чата
// @Tags         chat
// @Produce      json
// @Param        id path string true "Chat ID"
// @Param        limit query int false "Limit (default 50)"
// @Param        offset query int false "Offset"
// @Success      200 {array} domain.ChatMessage
// @Router       /v1/chats/{id}/messages [get]
// @Security     BearerAuth
func (h *ChatHandler) GetMessages(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	chatID := chi.URLParam(r, "id")
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	messages, err := h.service.GetMessages(r.Context(), chatID, limit, offset)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, messages)
}

// SendMessage godoc
// @Summary      Отправить сообщение в чат
// @Tags         chat
// @Accept       json
// @Produce      json
// @Param        id path string true "Chat ID"
// @Param        body body object true "text"
// @Success      200 {object} domain.ChatMessage
// @Router       /v1/chats/{id}/messages [post]
// @Security     BearerAuth
func (h *ChatHandler) SendMessage(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	chatID := chi.URLParam(r, "id")
	var body struct {
		Text string `json:"text"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}

	if body.Text == "" {
		jsonError(w, http.StatusBadRequest, "text is required")
		return
	}

	message, err := h.service.SendMessage(r.Context(), chatID, userID, body.Text)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, message)
}

// GetStats godoc
// @Summary      Получить общую статистику по чатам
// @Tags         chat
// @Produce      json
// @Success      200 {object} domain.ChatStats
// @Router       /v1/chats/stats [get]
// @Security     BearerAuth
func (h *ChatHandler) GetStats(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	stats, err := h.service.GetStats(r.Context(), userID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, stats)
}
