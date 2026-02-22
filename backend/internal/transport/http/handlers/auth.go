package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"

	"petio/backend/internal/domain"
	"petio/backend/internal/repository"
)

type AuthHandler struct {
	repo   repository.UserRepository
	secret string
	expHrs int
}

func NewAuthHandler(repo repository.UserRepository, secret string, expHrs int) *AuthHandler {
	return &AuthHandler{repo: repo, secret: secret, expHrs: expHrs}
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
	jsonResponse(w, http.StatusOK, map[string]string{"token": token})
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
	jsonResponse(w, http.StatusCreated, map[string]string{"token": token})
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
