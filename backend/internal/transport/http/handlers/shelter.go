package handlers

import (
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"petio/backend/internal/domain"
	"petio/backend/internal/repository"
)

type ShelterHandler struct {
	repo repository.ShelterRepository
}

func NewShelterHandler(repo repository.ShelterRepository) *ShelterHandler {
	return &ShelterHandler{repo: repo}
}

// List godoc
// @Summary      Список приютов
// @Tags         shelters
// @Produce      json
// @Success      200 {array} domain.Shelter
// @Router       /v1/shelters [get]
// @Security     BearerAuth
func (h *ShelterHandler) List(w http.ResponseWriter, r *http.Request) {
	list, err := h.repo.List(r.Context())
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusOK, list)
}

// Get godoc
// @Summary      Получить приют по ID
// @Tags         shelters
// @Produce      json
// @Param        id path string true "ID приюта"
// @Success      200 {object} domain.Shelter
// @Failure      404 {object} map[string]string "error"
// @Router       /v1/shelters/{id} [get]
// @Security     BearerAuth
func (h *ShelterHandler) Get(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if id == "" {
		jsonError(w, http.StatusBadRequest, "id required")
		return
	}
	s, err := h.repo.GetByID(r.Context(), id)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if s == nil {
		jsonError(w, http.StatusNotFound, "shelter not found")
		return
	}
	jsonResponse(w, http.StatusOK, s)
}

// Create godoc
// @Summary      Создать приют
// @Tags         shelters
// @Accept       json
// @Produce      json
// @Param        body body domain.Shelter true "приют"
// @Success      201 {object} domain.Shelter
// @Router       /v1/shelters [post]
// @Security     BearerAuth
func (h *ShelterHandler) Create(w http.ResponseWriter, r *http.Request) {
	var s domain.Shelter
	if err := json.NewDecoder(r.Body).Decode(&s); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	if err := h.repo.Create(r.Context(), &s); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusCreated, s)
}

// Update godoc
// @Summary      Обновить приют
// @Tags         shelters
// @Accept       json
// @Produce      json
// @Param        id path string true "ID приюта"
// @Param        body body domain.Shelter true "данные"
// @Success      200 {object} domain.Shelter
// @Router       /v1/shelters/{id} [put]
// @Security     BearerAuth
func (h *ShelterHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if id == "" {
		jsonError(w, http.StatusBadRequest, "id required")
		return
	}
	var s domain.Shelter
	if err := json.NewDecoder(r.Body).Decode(&s); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	s.ID = id
	if err := h.repo.Update(r.Context(), &s); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			jsonError(w, http.StatusNotFound, "shelter not found")
			return
		}
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusOK, s)
}

// Delete godoc
// @Summary      Удалить приют
// @Tags         shelters
// @Param        id path string true "ID приюта"
// @Success      204
// @Router       /v1/shelters/{id} [delete]
// @Security     BearerAuth
func (h *ShelterHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if id == "" {
		jsonError(w, http.StatusBadRequest, "id required")
		return
	}
	if err := h.repo.Delete(r.Context(), id); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			jsonError(w, http.StatusNotFound, "shelter not found")
			return
		}
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
