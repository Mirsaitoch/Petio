package handlers

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"petio/backend/internal/repository/postgres"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"petio/backend/internal/domain"
	"petio/backend/internal/repository"
)

type AuthHandler struct {
	repo        repository.UserRepository
	refreshRepo *postgres.RefreshTokenRepository
	secret      string
	expHrs      int
}

func NewAuthHandler(repo repository.UserRepository, refreshRepo *postgres.RefreshTokenRepository, secret string, expHrs int) *AuthHandler {
	return &AuthHandler{
		repo:        repo,
		refreshRepo: refreshRepo,
		secret:      secret,
		expHrs:      expHrs,
	}
}

// Login godoc
// @Summary      Вход
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        body body object true "email, password"
// @Success      200 {object} map[string]string "token"
// @Failure      401 {object} map[string]string "error"
// @Router       /v1/auth/login [post]
func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	u, err := h.repo.GetByEmail(r.Context(), body.Email)
	if err != nil || u == nil {
		jsonError(w, http.StatusUnauthorized, "invalid credentials")
		return
	}
	if err := bcrypt.CompareHashAndPassword([]byte(u.Password), []byte(body.Password)); err != nil {
		jsonError(w, http.StatusUnauthorized, "invalid credentials")
		return
	}
	token, err := h.issueToken(u.ID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	refreshToken, err := h.issueRefreshToken(r.Context(), u.ID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, map[string]string{
		"token":        token,
		"refreshToken": refreshToken,
	})
}

// Register godoc
// @Summary      Регистрация
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        body body object true "email, password"
// @Success      201 {object} map[string]string "token"
// @Failure      400,409 {object} map[string]string "error"
// @Router       /v1/auth/register [post]
func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}
	if body.Email == "" || body.Password == "" {
		jsonError(w, http.StatusBadRequest, "email and password required")
		return
	}
	existing, _ := h.repo.GetByEmail(r.Context(), body.Email)
	if existing != nil {
		jsonError(w, http.StatusConflict, "email already exists")
		return
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(body.Password), bcrypt.DefaultCost)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	u := &domain.User{Email: body.Email, Password: string(hash)}
	if err := h.repo.Create(r.Context(), u); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	token, err := h.issueToken(u.ID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	refreshToken, err := h.issueRefreshToken(r.Context(), u.ID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, map[string]string{
		"token":        token,
		"refreshToken": refreshToken,
	})
}

func (h *AuthHandler) issueToken(userID string) (string, error) {
	claims := jwt.RegisteredClaims{
		Subject:   userID,
		ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(h.expHrs) * time.Hour)),
		IssuedAt:  jwt.NewNumericDate(time.Now()),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(h.secret))
}

// RefreshToken godoc
// @Summary      Обновить access token
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        body body object true "refreshToken"
// @Success      200 {object} map[string]string "token, refreshToken"
// @Failure      401 {object} map[string]string "error"
// @Router       /v1/auth/refresh [post]
func (h *AuthHandler) RefreshToken(w http.ResponseWriter, r *http.Request) {
	var body struct {
		RefreshToken string `json:"refreshToken"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid body")
		return
	}

	tokenHash := hashToken(body.RefreshToken)
	userID, expiresAt, err := h.refreshRepo.GetUserIDByTokenHash(r.Context(), tokenHash)
	if err != nil || userID == "" {
		jsonError(w, http.StatusUnauthorized, "invalid refresh token")
		return
	}

	if time.Now().After(expiresAt) {
		_ = h.refreshRepo.DeleteByTokenHash(r.Context(), tokenHash)
		jsonError(w, http.StatusUnauthorized, "refresh token expired")
		return
	}

	// Удаляем старый refresh token
	_ = h.refreshRepo.DeleteByTokenHash(r.Context(), tokenHash)

	// Выпускаем новые токены
	token, err := h.issueToken(userID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	refreshToken, err := h.issueRefreshToken(r.Context(), userID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, map[string]string{
		"token":        token,
		"refreshToken": refreshToken,
	})
}

func (h *AuthHandler) issueRefreshToken(ctx context.Context, userID string) (string, error) {
	tokenStr := uuid.New().String() + uuid.New().String()
	tokenHash := hashToken(tokenStr)
	expiresAt := time.Now().Add(30 * 24 * time.Hour) // 30 дней

	if err := h.refreshRepo.Save(ctx, userID, tokenHash, expiresAt); err != nil {
		return "", err
	}

	return tokenStr, nil
}

func hashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}
