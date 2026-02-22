package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"petio/backend/internal/domain"
	"petio/backend/internal/repository"
	"petio/backend/internal/transport/http/handlers/middleware"
)

type ArticleHandler struct {
	repo repository.ArticleRepository
}

func NewArticleHandler(repo repository.ArticleRepository) *ArticleHandler {
	return &ArticleHandler{repo: repo}
}

// List godoc
// @Summary      Список статей
// @Tags         articles
// @Produce      json
// @Success      200 {array} domain.Article
// @Router       /v1/articles [get]
// @Security     BearerAuth
func (h *ArticleHandler) List(w http.ResponseWriter, r *http.Request) {
	list, err := h.repo.List(r.Context())
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusOK, list)
}

// Get godoc
// @Summary      Получить статью по ID
// @Tags         articles
// @Produce      json
// @Param        id path string true "ID статьи"
// @Success      200 {object} domain.Article
// @Failure      404 {object} map[string]string "error"
// @Router       /v1/articles/{id} [get]
// @Security     BearerAuth
func (h *ArticleHandler) Get(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if id == "" {
		jsonError(w, http.StatusBadRequest, "id required")
		return
	}
	a, err := h.repo.GetByID(r.Context(), id)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if a == nil {
		jsonError(w, http.StatusNotFound, "article not found")
		return
	}
	jsonResponse(w, http.StatusOK, a)
}

// Create godoc
// @Summary      Создать статью
// @Tags         articles
// @Accept       json
// @Produce      json
// @Param        body body domain.Article true "статья"
// @Success      201 {object} domain.Article
// @Router       /v1/articles [post]
// @Security     BearerAuth
func (h *ArticleHandler) Create(w http.ResponseWriter, r *http.Request) {
	_ = middleware.UserIDFromContext(r.Context())
	var a domain.Article
	if err := json.NewDecoder(r.Body).Decode(&a); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	if err := h.repo.Create(r.Context(), &a); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusCreated, a)
}

// Update godoc
// @Summary      Обновить статью
// @Tags         articles
// @Accept       json
// @Produce      json
// @Param        id path string true "ID статьи"
// @Param        body body domain.Article true "данные"
// @Success      200 {object} domain.Article
// @Router       /v1/articles/{id} [put]
// @Security     BearerAuth
func (h *ArticleHandler) Update(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if id == "" {
		jsonError(w, http.StatusBadRequest, "id required")
		return
	}
	var a domain.Article
	if err := json.NewDecoder(r.Body).Decode(&a); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	a.ID = id
	if err := h.repo.Update(r.Context(), &a); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusOK, a)
}

// Delete godoc
// @Summary      Удалить статью
// @Tags         articles
// @Param        id path string true "ID статьи"
// @Success      204
// @Router       /v1/articles/{id} [delete]
// @Security     BearerAuth
func (h *ArticleHandler) Delete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if id == "" {
		jsonError(w, http.StatusBadRequest, "id required")
		return
	}
	if err := h.repo.Delete(r.Context(), id); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
