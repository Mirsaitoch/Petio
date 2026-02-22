package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"petio/backend/internal/domain"
	"petio/backend/internal/repository"
	"petio/backend/internal/transport/http/handlers/middleware"
)

type ReminderHandler struct {
	repo repository.ReminderRepository
}

func NewReminderHandler(repo repository.ReminderRepository) *ReminderHandler {
	return &ReminderHandler{repo: repo}
}

// Get godoc
// @Summary      Получить напоминание по ID
// @Tags         reminders
// @Produce      json
// @Param        id path string true "ID напоминания"
// @Success      200 {object} domain.Reminder
// @Failure      404 {object} map[string]string "error"
// @Router       /v1/reminders/{id} [get]
// @Security     BearerAuth
func (h *ReminderHandler) Get(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		jsonError(w, http.StatusBadRequest, "id required")
		return
	}
	rem, err := h.repo.GetByID(r.Context(), id, userID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if rem == nil {
		jsonError(w, http.StatusNotFound, "reminder not found")
		return
	}
	jsonResponse(w, http.StatusOK, rem)
}

// List godoc
// @Summary      Список напоминаний
// @Tags         reminders
// @Produce      json
// @Param        petId query string false "фильтр по питомцу"
// @Success      200 {array} domain.Reminder
// @Router       /v1/reminders [get]
// @Security     BearerAuth
func (h *ReminderHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var petID *string
	if p := r.URL.Query().Get("petId"); p != "" {
		petID = &p
	}
	list, err := h.repo.List(r.Context(), userID, petID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusOK, list)
}

// Create godoc
// @Summary      Создать напоминание
// @Tags         reminders
// @Accept       json
// @Produce      json
// @Param        body body domain.Reminder true "напоминание"
// @Success      201 {object} domain.Reminder
// @Router       /v1/reminders [post]
// @Security     BearerAuth
func (h *ReminderHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var rem domain.Reminder
	if err := json.NewDecoder(r.Body).Decode(&rem); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	rem.UserID = userID
	if err := h.repo.Create(r.Context(), &rem); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusCreated, rem)
}

// Update godoc
// @Summary      Обновить напоминание
// @Tags         reminders
// @Accept       json
// @Produce      json
// @Param        id path string true "ID напоминания"
// @Param        body body domain.Reminder true "данные"
// @Success      200 {object} domain.Reminder
// @Router       /v1/reminders/{id} [put]
// @Security     BearerAuth
func (h *ReminderHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		jsonError(w, http.StatusBadRequest, "id required")
		return
	}
	var rem domain.Reminder
	if err := json.NewDecoder(r.Body).Decode(&rem); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	rem.ID = id
	rem.UserID = userID
	if err := h.repo.Update(r.Context(), &rem); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusOK, rem)
}

// Delete godoc
// @Summary      Удалить напоминание
// @Tags         reminders
// @Param        id path string true "ID напоминания"
// @Success      204
// @Router       /v1/reminders/{id} [delete]
// @Security     BearerAuth
func (h *ReminderHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	id := chi.URLParam(r, "id")
	if id == "" {
		jsonError(w, http.StatusBadRequest, "id required")
		return
	}
	if err := h.repo.Delete(r.Context(), id, userID); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
