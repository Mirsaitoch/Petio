package handlers

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"petio/backend/internal/email"
	"petio/backend/internal/metrics"
	"petio/backend/internal/repository/postgres"
	"petio/backend/internal/transport/http/handlers/middleware"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"petio/backend/internal/repository"
)

type AuthHandler struct {
	repo        repository.UserRepository
	refreshRepo *postgres.RefreshTokenRepository
	resetRepo   *postgres.PasswordResetTokenRepository
	verifyRepo  *postgres.EmailVerificationTokenRepository
	emailSender *email.Sender
	secret      string
	expHrs      int
}

func NewAuthHandler(
	repo repository.UserRepository,
	refreshRepo *postgres.RefreshTokenRepository,
	resetRepo *postgres.PasswordResetTokenRepository,
	verifyRepo *postgres.EmailVerificationTokenRepository,
	emailSender *email.Sender,
	secret string,
	expHrs int,
) *AuthHandler {
	return &AuthHandler{
		repo:        repo,
		refreshRepo: refreshRepo,
		resetRepo:   resetRepo,
		verifyRepo:  verifyRepo,
		emailSender: emailSender,
		secret:      secret,
		expHrs:      expHrs,
	}
}

// ──────────────────────────── LOGIN / REGISTER ────────────────────────────

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

	u, err := h.repo.CreateAnonymous(r.Context())
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if err := h.repo.LinkEmail(r.Context(), u.ID, body.Email, string(hash)); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	metrics.UserRegistrationsTotal.Inc()

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

// ──────────────────────────── TOKEN MANAGEMENT ────────────────────────────

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

	_ = h.refreshRepo.DeleteByTokenHash(r.Context(), tokenHash)

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
	expiresAt := time.Now().Add(30 * 24 * time.Hour)

	if err := h.refreshRepo.Save(ctx, userID, tokenHash, expiresAt); err != nil {
		return "", err
	}

	return tokenStr, nil
}

func hashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}

// ──────────────────────────── DEVICE AUTH ────────────────────────────

// LoginByDevice godoc
// @Summary      Вход / авторегистрация по device_id
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        body body object true "device_id"
// @Success      200 {object} map[string]interface{} "token, refreshToken, userId, isNew"
// @Failure      400 {object} map[string]string "error"
// @Router       /v1/auth/device [post]
func (h *AuthHandler) LoginByDevice(w http.ResponseWriter, r *http.Request) {
	var body struct {
		DeviceID string `json:"device_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.DeviceID == "" {
		jsonError(w, http.StatusBadRequest, "device_id required")
		return
	}

	users, err := h.repo.GetByDeviceID(r.Context(), body.DeviceID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	isNew := false
	var userID string

	if len(users) == 0 {
		u, err := h.repo.CreateAnonymous(r.Context())
		if err != nil {
			jsonError(w, http.StatusInternalServerError, err.Error())
			return
		}
		if err := h.repo.LinkDevice(r.Context(), u.ID, body.DeviceID); err != nil {
			jsonError(w, http.StatusInternalServerError, err.Error())
			return
		}
		metrics.UserRegistrationsTotal.Inc()
		userID = u.ID
		isNew = true
	} else {
		userID = users[0].ID
	}

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

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"token":        token,
		"refreshToken": refreshToken,
		"userId":       userID,
		"isNew":        isNew,
	})
}

// ListDeviceAccounts godoc
// @Summary      Список аккаунтов на устройстве
// @Tags         auth
// @Produce      json
// @Param        device_id query string true "device_id"
// @Success      200 {array} object "accounts"
// @Router       /v1/auth/device/accounts [get]
func (h *AuthHandler) ListDeviceAccounts(w http.ResponseWriter, r *http.Request) {
	deviceID := r.URL.Query().Get("device_id")
	if deviceID == "" {
		jsonError(w, http.StatusBadRequest, "device_id required")
		return
	}

	users, err := h.repo.GetByDeviceID(r.Context(), deviceID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	type accountInfo struct {
		UserID string `json:"userId"`
		Email  string `json:"email,omitempty"`
	}
	accounts := make([]accountInfo, 0, len(users))
	for _, u := range users {
		accounts = append(accounts, accountInfo{UserID: u.ID, Email: u.Email})
	}
	jsonResponse(w, http.StatusOK, accounts)
}

// SwitchDeviceAccount godoc
// @Summary      Переключиться на другой аккаунт на том же устройстве
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        body body object true "device_id, user_id"
// @Success      200 {object} map[string]string "token, refreshToken"
// @Failure      400,403 {object} map[string]string "error"
// @Router       /v1/auth/device/switch [post]
func (h *AuthHandler) SwitchDeviceAccount(w http.ResponseWriter, r *http.Request) {
	var body struct {
		DeviceID string `json:"device_id"`
		UserID   string `json:"user_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.DeviceID == "" || body.UserID == "" {
		jsonError(w, http.StatusBadRequest, "device_id and user_id required")
		return
	}

	ok, err := h.repo.DeviceHasUser(r.Context(), body.DeviceID, body.UserID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if !ok {
		jsonError(w, http.StatusForbidden, "account not linked to this device")
		return
	}

	token, err := h.issueToken(body.UserID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	refreshToken, err := h.issueRefreshToken(r.Context(), body.UserID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, map[string]string{
		"token":        token,
		"refreshToken": refreshToken,
	})
}

// ──────────────────────────── EMAIL LINKING + VERIFICATION ────────────────────────────

// LinkEmail godoc
// @Summary      Привязать email — отправляет код верификации на почту
// @Description  Email и пароль НЕ сохраняются до подтверждения кода через /auth/verify-email
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        body body object true "email, password"
// @Success      200 {object} map[string]string "status"
// @Failure      400,409 {object} map[string]string "error"
// @Router       /v1/auth/link-email [post]
// @Security     BearerAuth
func (h *AuthHandler) LinkEmail(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var body struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Email == "" || body.Password == "" {
		jsonError(w, http.StatusBadRequest, "email and password required")
		return
	}

	existing, _ := h.repo.GetByEmail(r.Context(), body.Email)
	if existing != nil {
		jsonError(w, http.StatusConflict, "email already in use")
		return
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(body.Password), bcrypt.DefaultCost)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	code := generateCode()
	tokenHash := hashToken(code)
	expiresAt := time.Now().Add(15 * time.Minute)

	if err := h.verifyRepo.Save(r.Context(), userID, body.Email, string(passwordHash), tokenHash, expiresAt); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	h.sendVerificationEmail(body.Email, code)

	jsonResponse(w, http.StatusOK, map[string]string{"status": "verification_sent"})
}

// VerifyEmail godoc
// @Summary      Подтвердить email кодом из письма
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        body body object true "code"
// @Success      200 {object} map[string]string "status"
// @Failure      400 {object} map[string]string "error"
// @Router       /v1/auth/verify-email [post]
// @Security     BearerAuth
func (h *AuthHandler) VerifyEmail(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	if userID == "" {
		jsonError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var body struct {
		Code string `json:"code"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Code == "" {
		jsonError(w, http.StatusBadRequest, "code required")
		return
	}

	tokenHash := hashToken(body.Code)
	storedUserID, emailAddr, passwordHash, expiresAt, err := h.verifyRepo.GetByTokenHash(r.Context(), tokenHash)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if storedUserID == "" {
		jsonError(w, http.StatusBadRequest, "invalid or expired code")
		return
	}
	if storedUserID != userID {
		jsonError(w, http.StatusBadRequest, "invalid or expired code")
		return
	}
	if time.Now().After(expiresAt) {
		_ = h.verifyRepo.DeleteByTokenHash(r.Context(), tokenHash)
		jsonError(w, http.StatusBadRequest, "code expired")
		return
	}

	// Check that email is still free
	existing, _ := h.repo.GetByEmail(r.Context(), emailAddr)
	if existing != nil {
		_ = h.verifyRepo.DeleteByTokenHash(r.Context(), tokenHash)
		jsonError(w, http.StatusConflict, "email already in use")
		return
	}

	if err := h.repo.LinkEmail(r.Context(), userID, emailAddr, passwordHash); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	_ = h.verifyRepo.DeleteByUserID(r.Context(), userID)

	jsonResponse(w, http.StatusOK, map[string]string{"status": "ok"})
}

// ──────────────────────────── PASSWORD RESET ────────────────────────────

// ForgotPassword godoc
// @Summary      Запросить сброс пароля
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        body body object true "email"
// @Success      200 {object} map[string]string "status"
// @Router       /v1/auth/forgot-password [post]
func (h *AuthHandler) ForgotPassword(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Email string `json:"email"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Email == "" {
		jsonError(w, http.StatusBadRequest, "email required")
		return
	}

	// Always return 200 to prevent email enumeration
	u, err := h.repo.GetByEmail(r.Context(), body.Email)
	if err != nil || u == nil {
		jsonResponse(w, http.StatusOK, map[string]string{"status": "ok"})
		return
	}

	code := generateCode()
	tokenHash := hashToken(code)
	expiresAt := time.Now().Add(15 * time.Minute)

	if err := h.resetRepo.Save(r.Context(), u.ID, tokenHash, expiresAt); err != nil {
		log.Printf("forgot-password: failed to save token: %v", err)
		jsonResponse(w, http.StatusOK, map[string]string{"status": "ok"})
		return
	}

	h.sendPasswordResetEmail(body.Email, code)

	jsonResponse(w, http.StatusOK, map[string]string{"status": "ok"})
}

// ResetPassword godoc
// @Summary      Сбросить пароль по коду из email
// @Tags         auth
// @Accept       json
// @Produce      json
// @Param        body body object true "email, code, new_password"
// @Success      200 {object} map[string]string "status"
// @Failure      400 {object} map[string]string "error"
// @Router       /v1/auth/reset-password [post]
func (h *AuthHandler) ResetPassword(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Email       string `json:"email"`
		Code        string `json:"code"`
		NewPassword string `json:"new_password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Code == "" || body.NewPassword == "" {
		jsonError(w, http.StatusBadRequest, "code and new_password required")
		return
	}

	tokenHash := hashToken(body.Code)
	userID, expiresAt, err := h.resetRepo.GetUserIDByTokenHash(r.Context(), tokenHash)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if userID == "" {
		jsonError(w, http.StatusBadRequest, "invalid or expired code")
		return
	}
	if time.Now().After(expiresAt) {
		_ = h.resetRepo.DeleteByTokenHash(r.Context(), tokenHash)
		jsonError(w, http.StatusBadRequest, "code expired")
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(body.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	if err := h.repo.UpdatePassword(r.Context(), userID, string(hash)); err != nil {
		jsonError(w, http.StatusInternalServerError, err.Error())
		return
	}

	_ = h.resetRepo.DeleteByTokenHash(r.Context(), tokenHash)

	jsonResponse(w, http.StatusOK, map[string]string{"status": "ok"})
}

// ──────────────────────────── HELPERS ────────────────────────────

func generateCode() string {
	n, err := rand.Int(rand.Reader, big.NewInt(999999))
	if err != nil {
		return "000000"
	}
	return fmt.Sprintf("%06d", n.Int64())
}

func (h *AuthHandler) sendVerificationEmail(toEmail, code string) {
	if h.emailSender == nil {
		log.Printf("EMAIL (no SMTP configured): verification code for %s: %s", toEmail, code)
		return
	}
	body := fmt.Sprintf(
		`<h2>Petio — подтверждение email</h2><p>Ваш код верификации: <b>%s</b></p><p>Код действителен 15 минут.</p>`,
		code,
	)
	if err := h.emailSender.Send(toEmail, "Petio: подтверждение email", body); err != nil {
		log.Printf("failed to send verification email to %s: %v", toEmail, err)
	}
}

func (h *AuthHandler) sendPasswordResetEmail(toEmail, code string) {
	if h.emailSender == nil {
		log.Printf("EMAIL (no SMTP configured): password reset code for %s: %s", toEmail, code)
		return
	}
	body := fmt.Sprintf(
		`<h2>Petio — сброс пароля</h2><p>Ваш код для сброса пароля: <b>%s</b></p><p>Код действителен 15 минут.</p>`,
		code,
	)
	if err := h.emailSender.Send(toEmail, "Petio: сброс пароля", body); err != nil {
		log.Printf("failed to send reset email to %s: %v", toEmail, err)
	}
}
