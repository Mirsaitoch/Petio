package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"petio/backend/internal/domain"
	"petio/backend/internal/repository"
	"petio/backend/internal/transport/http/handlers/middleware"
)

type PostHandler struct {
	repo repository.PostRepository
}

func NewPostHandler(repo repository.PostRepository) *PostHandler {
	return &PostHandler{repo: repo}
}

// Get godoc
// @Summary      Получить пост по ID
// @Tags         posts
// @Produce      json
// @Param        id path string true "ID поста"
// @Success      200 {object} domain.Post
// @Failure      404 {object} map[string]string "error"
// @Router       /v1/posts/{id} [get]
// @Security     BearerAuth
func (h *PostHandler) Get(w http.ResponseWriter, r *http.Request) {
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
	p, err := h.repo.GetByID(r.Context(), id, userID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if p == nil {
		jsonError(w, http.StatusNotFound, "post not found")
		return
	}
	jsonResponse(w, http.StatusOK, p)
}

// List godoc
// @Summary      Список постов
// @Tags         posts
// @Produce      json
// @Param        club query string false "фильтр по клубу"
// @Success      200 {array} domain.Post
// @Router       /v1/posts [get]
// @Security     BearerAuth
func (h *PostHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var club *string
	if c := r.URL.Query().Get("club"); c != "" {
		club = &c
	}
	list, err := h.repo.List(r.Context(), userID, club)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusOK, list)
}

// Create godoc
// @Summary      Создать пост
// @Tags         posts
// @Accept       json
// @Produce      json
// @Param        body body domain.Post true "пост"
// @Success      201 {object} domain.Post
// @Router       /v1/posts [post]
// @Security     BearerAuth
func (h *PostHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var p domain.Post
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	p.UserID = userID
	if err := h.repo.Create(r.Context(), &p); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusCreated, p)
}

// Update godoc
// @Summary      Обновить пост
// @Tags         posts
// @Accept       json
// @Produce      json
// @Param        id path string true "ID поста"
// @Param        body body domain.Post true "данные"
// @Success      200 {object} domain.Post
// @Router       /v1/posts/{id} [put]
// @Security     BearerAuth
func (h *PostHandler) Update(w http.ResponseWriter, r *http.Request) {
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
	var p domain.Post
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	p.ID = id
	p.UserID = userID
	if err := h.repo.Update(r.Context(), &p); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusOK, p)
}

// Delete godoc
// @Summary      Удалить пост
// @Tags         posts
// @Param        id path string true "ID поста"
// @Success      204
// @Router       /v1/posts/{id} [delete]
// @Security     BearerAuth
func (h *PostHandler) Delete(w http.ResponseWriter, r *http.Request) {
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

// Like godoc
// @Summary      Поставить/убрать лайк
// @Tags         posts
// @Accept       json
// @Param        id path string true "ID поста"
// @Param        body body object true "liked: true/false"
// @Success      200
// @Router       /v1/posts/{id}/like [post]
// @Security     BearerAuth
func (h *PostHandler) Like(w http.ResponseWriter, r *http.Request) {
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
	var body struct {
		Liked bool `json:"liked"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	if err := h.repo.SetLiked(r.Context(), id, userID, body.Liked); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.WriteHeader(http.StatusOK)
}

// AddComment godoc
// @Summary      Добавить комментарий к посту
// @Tags         posts
// @Accept       json
// @Produce      json
// @Param        postId path string true "ID поста"
// @Param        body body domain.Comment true "комментарий"
// @Success      201 {object} domain.Comment
// @Router       /v1/posts/{postId}/comments [post]
// @Security     BearerAuth
func (h *PostHandler) AddComment(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	postID := chi.URLParam(r, "postId")
	if postID == "" {
		jsonError(w, http.StatusBadRequest, "postId required")
		return
	}
	var c domain.Comment
	if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	c.PostID = postID
	if err := h.repo.AddComment(r.Context(), postID, &c); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusCreated, c)
}
