package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"petio/backend/internal/domain"
	"petio/backend/internal/repository"
	"petio/backend/internal/transport/http/handlers/middleware"
)

type WeightHandler struct {
	repo repository.WeightRepository
}

func NewWeightHandler(repo repository.WeightRepository) *WeightHandler {
	return &WeightHandler{repo: repo}
}

// Get godoc
// @Summary      Получить запись веса по дате
// @Tags         weight
// @Produce      json
// @Param        petId path string true "ID питомца"
// @Param        date path string true "Дата (YYYY-MM-DD)"
// @Success      200 {object} domain.WeightRecord
// @Failure      404 {object} map[string]string "error"
// @Router       /v1/pets/{petId}/weight/{date} [get]
// @Security     BearerAuth
func (h *WeightHandler) Get(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	petID := chi.URLParam(r, "petId")
	date := chi.URLParam(r, "date")
	if petID == "" || date == "" {
		jsonError(w, http.StatusBadRequest, "petId and date required")
		return
	}
	rec, err := h.repo.GetByPetIDAndDate(r.Context(), petID, date, userID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if rec == nil {
		jsonError(w, http.StatusNotFound, "weight record not found")
		return
	}
	jsonResponse(w, http.StatusOK, rec)
}

// List godoc
// @Summary      Список записей веса питомца
// @Tags         weight
// @Produce      json
// @Param        petId path string true "ID питомца"
// @Success      200 {array} domain.WeightRecord
// @Router       /v1/pets/{petId}/weight [get]
// @Security     BearerAuth
func (h *WeightHandler) List(w http.ResponseWriter, r *http.Request) {
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

// Add godoc
// @Summary      Добавить запись веса
// @Tags         weight
// @Accept       json
// @Produce      json
// @Param        petId path string true "ID питомца"
// @Param        body body domain.WeightRecord true "date, weight"
// @Success      201
// @Router       /v1/pets/{petId}/weight [post]
// @Security     BearerAuth
func (h *WeightHandler) Add(w http.ResponseWriter, r *http.Request) {
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
	var rec domain.WeightRecord
	if err := json.NewDecoder(r.Body).Decode(&rec); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	if err := h.repo.Add(r.Context(), petID, userID, rec); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.WriteHeader(http.StatusCreated)
}

// Update godoc
// @Summary      Обновить запись веса
// @Tags         weight
// @Accept       json
// @Produce      json
// @Param        petId path string true "ID питомца"
// @Param        date path string true "Дата (YYYY-MM-DD)"
// @Param        body body domain.WeightRecord true "weight"
// @Success      200 {object} domain.WeightRecord
// @Router       /v1/pets/{petId}/weight/{date} [put]
// @Security     BearerAuth
func (h *WeightHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	petID := chi.URLParam(r, "petId")
	date := chi.URLParam(r, "date")
	if petID == "" || date == "" {
		jsonError(w, http.StatusBadRequest, "petId and date required")
		return
	}
	var rec domain.WeightRecord
	if err := json.NewDecoder(r.Body).Decode(&rec); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	rec.Date = date
	if err := h.repo.Update(r.Context(), petID, userID, rec); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusOK, rec)
}

// Delete godoc
// @Summary      Удалить запись веса
// @Tags         weight
// @Param        petId path string true "ID питомца"
// @Param        date path string true "Дата (YYYY-MM-DD)"
// @Success      204
// @Router       /v1/pets/{petId}/weight/{date} [delete]
// @Security     BearerAuth
func (h *WeightHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	petID := chi.URLParam(r, "petId")
	date := chi.URLParam(r, "date")
	if petID == "" || date == "" {
		jsonError(w, http.StatusBadRequest, "petId and date required")
		return
	}
	if err := h.repo.Delete(r.Context(), petID, date, userID); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
