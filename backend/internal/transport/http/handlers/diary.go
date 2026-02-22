package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"petio/backend/internal/domain"
	"petio/backend/internal/repository"
	"petio/backend/internal/transport/http/handlers/middleware"
)

type DiaryHandler struct {
	repo repository.DiaryRepository
}

func NewDiaryHandler(repo repository.DiaryRepository) *DiaryHandler {
	return &DiaryHandler{repo: repo}
}

// Get godoc
// @Summary      Получить запись дневника по ID
// @Tags         diary
// @Produce      json
// @Param        id path string true "ID записи"
// @Success      200 {object} domain.HealthDiaryEntry
// @Failure      404 {object} map[string]string "error"
// @Router       /v1/diary/{id} [get]
// @Security     BearerAuth
func (h *DiaryHandler) Get(w http.ResponseWriter, r *http.Request) {
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
	e, err := h.repo.GetByID(r.Context(), id, userID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if e == nil {
		jsonError(w, http.StatusNotFound, "entry not found")
		return
	}
	jsonResponse(w, http.StatusOK, e)
}

// List godoc
// @Summary      Список записей дневника питомца
// @Tags         diary
// @Produce      json
// @Param        petId path string true "ID питомца"
// @Success      200 {array} domain.HealthDiaryEntry
// @Router       /v1/pets/{petId}/diary [get]
// @Security     BearerAuth
func (h *DiaryHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	petID := chi.URLParam(r, "petId")
	if petID == "" {
		jsonError(w, http.StatusBadRequest, "petId required")
		return
	}
	list, err := h.repo.GetByPetID(r.Context(), petID, userID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusOK, list)
}

// Create godoc
// @Summary      Создать запись в дневнике
// @Tags         diary
// @Accept       json
// @Produce      json
// @Param        petId path string true "ID питомца"
// @Param        body body domain.HealthDiaryEntry true "запись"
// @Success      201 {object} domain.HealthDiaryEntry
// @Router       /v1/pets/{petId}/diary [post]
// @Security     BearerAuth
func (h *DiaryHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	petID := chi.URLParam(r, "petId")
	if petID == "" {
		jsonError(w, http.StatusBadRequest, "petId required")
		return
	}
	var e domain.HealthDiaryEntry
	if err := json.NewDecoder(r.Body).Decode(&e); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	e.PetID = petID
	e.UserID = userID
	if err := h.repo.Create(r.Context(), &e); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusCreated, e)
}

// Update godoc
// @Summary      Обновить запись дневника
// @Tags         diary
// @Accept       json
// @Param        id path string true "ID записи"
// @Param        body body domain.HealthDiaryEntry true "данные"
// @Success      200
// @Router       /v1/diary/{id} [put]
// @Security     BearerAuth
func (h *DiaryHandler) Update(w http.ResponseWriter, r *http.Request) {
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
	var e domain.HealthDiaryEntry
	if err := json.NewDecoder(r.Body).Decode(&e); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	e.ID = id
	e.UserID = userID
	if err := h.repo.Update(r.Context(), &e); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.WriteHeader(http.StatusOK)
}

// Delete godoc
// @Summary      Удалить запись дневника
// @Tags         diary
// @Param        id path string true "ID записи"
// @Success      204
// @Router       /v1/diary/{id} [delete]
// @Security     BearerAuth
func (h *DiaryHandler) Delete(w http.ResponseWriter, r *http.Request) {
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
