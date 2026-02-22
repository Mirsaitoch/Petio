package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"petio/backend/internal/domain"
	"petio/backend/internal/repository"
	"petio/backend/internal/transport/http/handlers/middleware"
)

type PetHandler struct {
	repo repository.PetRepository
}

func NewPetHandler(repo repository.PetRepository) *PetHandler {
	return &PetHandler{repo: repo}
}

// List godoc
// @Summary      Список питомцев
// @Tags         pets
// @Produce      json
// @Success      200 {array} domain.Pet
// @Router       /v1/pets [get]
// @Security     BearerAuth
func (h *PetHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	list, err := h.repo.List(r.Context(), userID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusOK, list)
}

// Get godoc
// @Summary      Получить питомца по ID
// @Tags         pets
// @Produce      json
// @Param        id path string true "ID питомца"
// @Success      200 {object} domain.Pet
// @Failure      404 {object} map[string]string "error"
// @Router       /v1/pets/{id} [get]
// @Security     BearerAuth
func (h *PetHandler) Get(w http.ResponseWriter, r *http.Request) {
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
	pet, err := h.repo.GetByID(r.Context(), id, userID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if pet == nil {
		jsonError(w, http.StatusNotFound, "pet not found")
		return
	}
	jsonResponse(w, http.StatusOK, pet)
}

// Create godoc
// @Summary      Добавить питомца
// @Tags         pets
// @Accept       json
// @Produce      json
// @Param        body body domain.Pet true "питомец"
// @Success      201 {object} domain.Pet
// @Router       /v1/pets [post]
// @Security     BearerAuth
func (h *PetHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var pet domain.Pet
	if err := json.NewDecoder(r.Body).Decode(&pet); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	pet.UserID = userID
	if err := h.repo.Create(r.Context(), &pet); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusCreated, pet)
}

// Update godoc
// @Summary      Обновить питомца
// @Tags         pets
// @Accept       json
// @Produce      json
// @Param        id path string true "ID питомца"
// @Param        body body domain.Pet true "данные питомца"
// @Success      200 {object} domain.Pet
// @Router       /v1/pets/{id} [put]
// @Security     BearerAuth
func (h *PetHandler) Update(w http.ResponseWriter, r *http.Request) {
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
	var pet domain.Pet
	if err := json.NewDecoder(r.Body).Decode(&pet); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	pet.ID = id
	pet.UserID = userID
	if err := h.repo.Update(r.Context(), &pet); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusOK, pet)
}

// Delete godoc
// @Summary      Удалить питомца
// @Tags         pets
// @Param        id path string true "ID питомца"
// @Success      204
// @Router       /v1/pets/{id} [delete]
// @Security     BearerAuth
func (h *PetHandler) Delete(w http.ResponseWriter, r *http.Request) {
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
