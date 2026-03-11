package handlers

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"petio/backend/clients/moderation"

	"petio/backend/internal/repository"
	"petio/backend/internal/transport/http/handlers/middleware"
)

type ProfileHandler struct {
	repo       repository.UserRepository
	mod        *moderation.Client
	thresholds moderation.Thresholds
}

func NewProfileHandler(
	repo repository.UserRepository,
	mod *moderation.Client,
	thresholds moderation.Thresholds,
) *ProfileHandler {
	return &ProfileHandler{repo: repo, mod: mod, thresholds: thresholds}
}

// Get godoc
// @Summary      Получить профиль текущего пользователя
// @Tags         profile
// @Produce      json
// @Success      200 {object} domain.UserProfile
// @Failure      404 {object} map[string]string "error"
// @Router       /v1/profile [get]
// @Security     BearerAuth
func (h *ProfileHandler) Get(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	p, err := h.repo.GetProfile(r.Context(), userID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if p == nil {
		jsonError(w, http.StatusNotFound, "profile not found")
		return
	}
	jsonResponse(w, http.StatusOK, p)
}

// Update godoc
// @Summary      Обновить профиль
// @Tags         profile
// @Accept       json
// @Produce      json
// @Param        body body object true "name, username, avatar, bio"
// @Success      200 {object} domain.UserProfile
// @Router       /v1/profile [put]
// @Security     BearerAuth
func (h *ProfileHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var p struct {
		Name     string  `json:"name"`
		Username string  `json:"username"`
		Avatar   *string `json:"avatar,omitempty"`
		Bio      string  `json:"bio"`
	}
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}

	// ── text moderation for profile fields ──
	if h.mod != nil {
		for _, text := range []string{p.Bio, p.Name, p.Username} {
			if text == "" {
				continue
			}
			scores, err := h.mod.CheckText(r.Context(), text)
			if err != nil {
				log.Printf("WARNING: profile text moderation failed: %v", err)
				continue
			}
			if scores == nil {
				continue
			}
			d := h.thresholds.Evaluate(scores)
			if d.Block {
				jsonError(w, http.StatusUnprocessableEntity,
					fmt.Sprintf("text rejected: %s", d.Reason))
				return
			}
		}
	}

	profile, err := h.repo.GetProfile(r.Context(), userID)
	if err != nil || profile == nil {
		jsonError(w, http.StatusInternalServerError, "profile not found")
		return
	}
	profile.Name = p.Name
	profile.Username = p.Username
	profile.Avatar = p.Avatar
	profile.Bio = p.Bio
	profile.UserID = userID
	if err := h.repo.UpdateProfile(r.Context(), profile); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusOK, profile)
}
