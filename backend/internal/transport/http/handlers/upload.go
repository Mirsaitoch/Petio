package handlers

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"path"
	"petio/backend/clients/moderation"
	"strings"

	"github.com/google/uuid"

	"petio/backend/clients/s3"
	"petio/backend/internal/transport/http/handlers/middleware"
)

const maxUploadSize = 10 << 20 // 10 MB

var allowedImageTypes = map[string]bool{
	"image/jpeg": true, "image/jpg": true, "image/png": true, "image/gif": true, "image/webp": true,
}

func extByContentType(ct string) string {
	switch ct {
	case "image/jpeg", "image/jpg":
		return ".jpg"
	case "image/png":
		return ".png"
	case "image/gif":
		return ".gif"
	case "image/webp":
		return ".webp"
	default:
		return ""
	}
}

type UploadHandler struct {
	s3  *s3.Client
	mod *moderation.Client
}

func NewUploadHandler(s3Client *s3.Client, modClient *moderation.Client) *UploadHandler {
	return &UploadHandler{s3: s3Client, mod: modClient}
}

// UploadPetPhoto godoc
// @Summary      Загрузка фото питомца
// @Tags         upload
// @Accept       multipart/form-data
// @Produce      json
// @Param        file formData file true "Изображение (JPEG, PNG, GIF, WebP, до 10 MB)"
// @Success      201 {object} map[string]string "url"
// @Failure      400,413,503 {object} map[string]string "error"
// @Router       /v1/upload/pet-photo [post]
// @Security     BearerAuth
func (h *UploadHandler) UploadPetPhoto(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	h.upload(w, r, userID, "pets")
}

// UploadPostImage godoc
// @Summary      Загрузка картинки к посту
// @Tags         upload
// @Accept       multipart/form-data
// @Produce      json
// @Param        file formData file true "Изображение (JPEG, PNG, GIF, WebP, до 10 MB)"
// @Success      201 {object} map[string]string "url"
// @Failure      400,413,503 {object} map[string]string "error"
// @Router       /v1/upload/post-image [post]
// @Security     BearerAuth
func (h *UploadHandler) UploadPostImage(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	h.upload(w, r, userID, "posts")
}

func (h *UploadHandler) upload(w http.ResponseWriter, r *http.Request, userID, prefix string) {
	if h.s3 == nil {
		jsonError(w, http.StatusServiceUnavailable, "upload disabled: S3 client not initialized")
		return
	}
	if r.ContentLength > maxUploadSize {
		jsonError(w, http.StatusRequestEntityTooLarge, "file too large (max 10 MB)")
		return
	}
	if err := r.ParseMultipartForm(maxUploadSize); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid multipart form")
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		jsonError(w, http.StatusBadRequest, "missing or invalid file")
		return
	}
	defer file.Close()

	ct := header.Header.Get("Content-Type")
	if ct == "" {
		ct = "application/octet-stream"
	}
	if !allowedImageTypes[ct] {
		jsonError(w, http.StatusBadRequest, "only images (jpeg, png, gif, webp) allowed")
		return
	}

	body, err := io.ReadAll(io.LimitReader(file, maxUploadSize))
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if len(body) == 0 {
		jsonError(w, http.StatusBadRequest, "empty file")
		return
	}

	// ── ML image moderation ──
	if h.mod != nil {
		scores, err := h.mod.CheckImage(r.Context(), body, header.Filename)
		if err != nil {
			log.Printf("WARNING: image moderation failed: %v", err)
		} else if scores != nil && scores.Block {
			reason := "inappropriate_content"
			if scores.Reason != nil {
				reason = *scores.Reason
			}
			jsonError(w, http.StatusUnprocessableEntity,
				fmt.Sprintf("image rejected: %s (nsfw=%.2f, porn=%.2f, violence=%.2f, abuse=%.2f)",
					reason, scores.NSFWScore, scores.PornScore, scores.ViolenceScore, scores.AbuseScore))
			return
		}
	}

	ext := extByContentType(ct)
	if ext == "" {
		if e := strings.ToLower(path.Ext(header.Filename)); e == ".jpg" || e == ".jpeg" || e == ".png" || e == ".gif" || e == ".webp" {
			ext = e
			if ext == ".jpeg" {
				ext = ".jpg"
			}
		} else {
			ext = ".jpg"
		}
	}

	key := fmt.Sprintf("%s/%s/%s%s", prefix, userID, uuid.New().String(), ext)
	urlStr, err := h.s3.Upload(r.Context(), key, body, ct)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	jsonResponse(w, http.StatusCreated, map[string]string{"url": urlStr})
}

// UploadAvatar godoc
// @Summary      Загрузка аватара пользователя
// @Tags         upload
// @Accept       multipart/form-data
// @Produce      json
// @Param        file formData file true "Изображение (JPEG, PNG, GIF, WebP, до 10 MB)"
// @Success      201 {object} map[string]string "url"
// @Failure      400,413,503 {object} map[string]string "error"
// @Router       /v1/upload/avatar [post]
// @Security     BearerAuth
func (h *UploadHandler) UploadAvatar(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	h.upload(w, r, userID, "avatars")
}
