// Package tests содержит интеграционные тесты API.
// Запуск: go test ./tests/ -tags=integration
// Требует: PostgreSQL на DATABASE_URL (или docker-compose postgres).
package tests

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.uber.org/zap"

	"petio/backend/internal/app"
	"petio/backend/internal/config"
)

var (
	ts    *httptest.Server
	token string
)

func TestMain(m *testing.M) {
	os.Setenv("APP_ENV", "test")
	if os.Getenv("DATABASE_URL") == "" {
		os.Setenv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/petio_test?sslmode=disable")
	}

	log := zap.NewNop()
	cfg := config.Load(log)
	application, err := app.New(cfg, log)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to create app: %v\n", err)
		os.Exit(1)
	}

	ts = httptest.NewServer(application.Handler())
	defer ts.Close()

	os.Exit(m.Run())
}

// ──────────────────────── helpers ────────────────────────

func apiURL(path string) string {
	return ts.URL + path
}

func doJSON(t *testing.T, method, path string, body interface{}, headers ...string) *http.Response {
	t.Helper()
	var reader io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		reader = bytes.NewReader(b)
	}
	req, err := http.NewRequest(method, apiURL(path), reader)
	require.NoError(t, err)
	req.Header.Set("Content-Type", "application/json")
	for i := 0; i+1 < len(headers); i += 2 {
		req.Header.Set(headers[i], headers[i+1])
	}
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	return resp
}

func doAuthJSON(t *testing.T, method, path string, body interface{}) *http.Response {
	t.Helper()
	require.NotEmpty(t, token, "token not set — run auth tests first")
	return doJSON(t, method, path, body, "Authorization", "Bearer "+token)
}

func readBody(t *testing.T, resp *http.Response) map[string]interface{} {
	t.Helper()
	defer resp.Body.Close()
	var m map[string]interface{}
	err := json.NewDecoder(resp.Body).Decode(&m)
	require.NoError(t, err)
	return m
}

func readArray(t *testing.T, resp *http.Response) []interface{} {
	t.Helper()
	defer resp.Body.Close()
	var arr []interface{}
	err := json.NewDecoder(resp.Body).Decode(&arr)
	require.NoError(t, err)
	return arr
}

// ──────────────────────── Health ────────────────────────

func TestHealth(t *testing.T) {
	resp, err := http.Get(apiURL("/health"))
	require.NoError(t, err)
	defer resp.Body.Close()
	assert.Equal(t, 200, resp.StatusCode)
}

// ──────────────────────── Auth ────────────────────────

func TestAuth_Register(t *testing.T) {
	resp := doJSON(t, "POST", "/v1/auth/register", map[string]string{
		"email":    "ci-test@petio.dev",
		"password": "testpass123",
	})
	body := readBody(t, resp)

	if resp.StatusCode == http.StatusConflict {
		// уже есть — логинимся
		resp2 := doJSON(t, "POST", "/v1/auth/login", map[string]string{
			"email":    "ci-test@petio.dev",
			"password": "testpass123",
		})
		body = readBody(t, resp2)
		assert.Equal(t, 200, resp2.StatusCode)
	} else {
		assert.Equal(t, 200, resp.StatusCode)
	}

	require.NotEmpty(t, body["token"])
	require.NotEmpty(t, body["refreshToken"])
	token = body["token"].(string)
}

func TestAuth_Login(t *testing.T) {
	resp := doJSON(t, "POST", "/v1/auth/login", map[string]string{
		"email":    "ci-test@petio.dev",
		"password": "testpass123",
	})
	assert.Equal(t, 200, resp.StatusCode)

	body := readBody(t, resp)
	require.NotEmpty(t, body["token"])
	token = body["token"].(string)
}

func TestAuth_LoginWrongPassword(t *testing.T) {
	resp := doJSON(t, "POST", "/v1/auth/login", map[string]string{
		"email":    "ci-test@petio.dev",
		"password": "wrongpass",
	})
	assert.Equal(t, 401, resp.StatusCode)
	resp.Body.Close()
}

func TestAuth_DeviceAuth(t *testing.T) {
	resp := doJSON(t, "POST", "/v1/auth/device", map[string]string{
		"device_id": "ci-test-device-001",
	})
	assert.Equal(t, 200, resp.StatusCode)

	body := readBody(t, resp)
	require.NotEmpty(t, body["token"])
	require.NotEmpty(t, body["userId"])
}

func TestAuth_RefreshToken(t *testing.T) {
	// Сначала логин чтобы получить refresh token
	resp := doJSON(t, "POST", "/v1/auth/login", map[string]string{
		"email":    "ci-test@petio.dev",
		"password": "testpass123",
	})
	body := readBody(t, resp)
	refreshToken := body["refreshToken"].(string)

	resp2 := doJSON(t, "POST", "/v1/auth/refresh", map[string]string{
		"refreshToken": refreshToken,
	})
	assert.Equal(t, 200, resp2.StatusCode)

	body2 := readBody(t, resp2)
	require.NotEmpty(t, body2["token"])
	token = body2["token"].(string)
}

func TestAuth_ForgotPassword(t *testing.T) {
	// Всегда 200 (не раскрывает существование email)
	resp := doJSON(t, "POST", "/v1/auth/forgot-password", map[string]string{
		"email": "nonexistent@petio.dev",
	})
	assert.Equal(t, 200, resp.StatusCode)
	resp.Body.Close()
}

// ──────────────────────── Profile ────────────────────────

func TestProfile_Get(t *testing.T) {
	resp := doAuthJSON(t, "GET", "/v1/profile", nil)
	assert.Equal(t, 200, resp.StatusCode)
	resp.Body.Close()
}

func TestProfile_Update(t *testing.T) {
	resp := doAuthJSON(t, "PUT", "/v1/profile", map[string]string{
		"name":     "CI Test User",
		"username": "citest",
		"bio":      "testing",
	})
	assert.Equal(t, 200, resp.StatusCode)

	body := readBody(t, resp)
	assert.Equal(t, "CI Test User", body["name"])
}

// ──────────────────────── Pets ────────────────────────

var testPetID string

func TestPets_Create(t *testing.T) {
	resp := doAuthJSON(t, "POST", "/v1/pets", map[string]interface{}{
		"name":       "Тестовый Барсик",
		"species":    "cat",
		"breed":      "дворовый",
		"age":        2,
		"weight":     4.5,
		"birth_date": "2022-01-15T00:00:00Z",
	})
	assert.Equal(t, 201, resp.StatusCode)

	body := readBody(t, resp)
	require.NotEmpty(t, body["id"])
	testPetID = body["id"].(string)
}

func TestPets_List(t *testing.T) {
	resp := doAuthJSON(t, "GET", "/v1/pets", nil)
	assert.Equal(t, 200, resp.StatusCode)

	arr := readArray(t, resp)
	assert.GreaterOrEqual(t, len(arr), 1)
}

func TestPets_GetByID(t *testing.T) {
	require.NotEmpty(t, testPetID)
	resp := doAuthJSON(t, "GET", "/v1/pets/"+testPetID, nil)
	assert.Equal(t, 200, resp.StatusCode)

	body := readBody(t, resp)
	assert.Equal(t, "Тестовый Барсик", body["name"])
}

func TestPets_Update(t *testing.T) {
	require.NotEmpty(t, testPetID)
	resp := doAuthJSON(t, "PUT", "/v1/pets/"+testPetID, map[string]interface{}{
		"name":       "Обновлённый Барсик",
		"species":    "cat",
		"breed":      "дворовый",
		"age":        3,
		"weight":     5.0,
		"birth_date": "2022-01-15T00:00:00Z",
	})
	assert.Equal(t, 200, resp.StatusCode)
	resp.Body.Close()
}

func TestPets_Delete(t *testing.T) {
	require.NotEmpty(t, testPetID)
	resp := doAuthJSON(t, "DELETE", "/v1/pets/"+testPetID, nil)
	assert.Equal(t, 204, resp.StatusCode)
	resp.Body.Close()
}

// ──────────────────────── Reminders ────────────────────────

var testReminderID string

func TestReminders_Create(t *testing.T) {
	// Сначала создадим питомца для напоминания
	resp := doAuthJSON(t, "POST", "/v1/pets", map[string]interface{}{
		"name":       "Reminder Pet",
		"species":    "dog",
		"breed":      "test",
		"age":        1,
		"weight":     3.0,
		"birth_date": "2023-01-01T00:00:00Z",
	})
	petBody := readBody(t, resp)
	petID := petBody["id"].(string)

	resp2 := doAuthJSON(t, "POST", "/v1/reminders", map[string]interface{}{
		"petId": petID,
		"type":  "feeding",
		"title": "Покормить",
		"date":  "2026-04-01T00:00:00Z",
		"time":  "09:00",
	})
	assert.Equal(t, 201, resp2.StatusCode)

	body := readBody(t, resp2)
	require.NotEmpty(t, body["id"])
	testReminderID = body["id"].(string)
}

func TestReminders_List(t *testing.T) {
	resp := doAuthJSON(t, "GET", "/v1/reminders", nil)
	assert.Equal(t, 200, resp.StatusCode)

	arr := readArray(t, resp)
	assert.GreaterOrEqual(t, len(arr), 1)
}

// ──────────────────────── Articles ────────────────────────

var testArticleID string

func TestArticles_Create(t *testing.T) {
	resp := doAuthJSON(t, "POST", "/v1/articles", map[string]interface{}{
		"title":       "Тестовая статья",
		"description": "Описание тестовой статьи",
		"category":    "health",
		"petType":     "cat",
		"careType":    "nutrition",
		"readTime":    5,
	})
	assert.Equal(t, 201, resp.StatusCode)

	body := readBody(t, resp)
	require.NotEmpty(t, body["id"])
	testArticleID = body["id"].(string)
}

func TestArticles_List(t *testing.T) {
	resp := doAuthJSON(t, "GET", "/v1/articles", nil)
	assert.Equal(t, 200, resp.StatusCode)

	arr := readArray(t, resp)
	assert.GreaterOrEqual(t, len(arr), 1)
}

func TestArticles_GetByID(t *testing.T) {
	require.NotEmpty(t, testArticleID)
	resp := doAuthJSON(t, "GET", "/v1/articles/"+testArticleID, nil)
	assert.Equal(t, 200, resp.StatusCode)
	resp.Body.Close()
}

// ──────────────────────── Posts ────────────────────────

var testPostID string

func TestPosts_Create(t *testing.T) {
	resp := doAuthJSON(t, "POST", "/v1/posts", map[string]interface{}{
		"content": "Тестовый пост для CI",
		"club":    "cats",
	})
	assert.Equal(t, 201, resp.StatusCode)

	body := readBody(t, resp)
	require.NotEmpty(t, body["id"])
	testPostID = body["id"].(string)
}

func TestPosts_List(t *testing.T) {
	resp := doAuthJSON(t, "GET", "/v1/posts", nil)
	assert.Equal(t, 200, resp.StatusCode)
	resp.Body.Close()
}

func TestPosts_GetByID(t *testing.T) {
	require.NotEmpty(t, testPostID)
	resp := doAuthJSON(t, "GET", "/v1/posts/"+testPostID, nil)
	assert.Equal(t, 200, resp.StatusCode)
	resp.Body.Close()
}

func TestPosts_Like(t *testing.T) {
	require.NotEmpty(t, testPostID)
	resp := doAuthJSON(t, "POST", "/v1/posts/"+testPostID+"/like", map[string]bool{
		"liked": true,
	})
	assert.Equal(t, 200, resp.StatusCode)
	resp.Body.Close()
}

func TestPosts_AddComment(t *testing.T) {
	require.NotEmpty(t, testPostID)
	resp := doAuthJSON(t, "POST", "/v1/posts/"+testPostID+"/comments", map[string]string{
		"content": "Тестовый комментарий",
	})
	assert.Equal(t, 201, resp.StatusCode)
	resp.Body.Close()
}

// ──────────────────────── Shelters ────────────────────────

var testShelterID string

func TestShelters_Create(t *testing.T) {
	resp := doAuthJSON(t, "POST", "/v1/shelters", map[string]interface{}{
		"name":            "Тестовый приют",
		"tagline":         "Помогаем животным",
		"imageURL":        "https://example.com/shelter.jpg",
		"category":        "Приют",
		"city":            "Москва",
		"founded":         "2020",
		"phone":           "+7 999 123-45-67",
		"website":         "shelter-test.ru",
		"description":     "Тестовый приют для CI",
		"longDescription": "Длинное описание тестового приюта",
		"tags":            []string{"тест", "CI"},
		"needs":           []string{"корма", "волонтёры"},
	})
	assert.Equal(t, 201, resp.StatusCode)

	body := readBody(t, resp)
	require.NotEmpty(t, body["id"])
	testShelterID = body["id"].(string)
}

func TestShelters_List(t *testing.T) {
	resp := doAuthJSON(t, "GET", "/v1/shelters", nil)
	assert.Equal(t, 200, resp.StatusCode)

	arr := readArray(t, resp)
	assert.GreaterOrEqual(t, len(arr), 1)
}

func TestShelters_GetByID(t *testing.T) {
	require.NotEmpty(t, testShelterID)
	resp := doAuthJSON(t, "GET", "/v1/shelters/"+testShelterID, nil)
	assert.Equal(t, 200, resp.StatusCode)

	body := readBody(t, resp)
	assert.Equal(t, "Тестовый приют", body["name"])
}

func TestShelters_Update(t *testing.T) {
	require.NotEmpty(t, testShelterID)
	resp := doAuthJSON(t, "PUT", "/v1/shelters/"+testShelterID, map[string]interface{}{
		"name":            "Обновлённый приют",
		"tagline":         "Помогаем животным",
		"imageURL":        "https://example.com/shelter2.jpg",
		"category":        "Фонд",
		"city":            "СПб",
		"founded":         "2020",
		"phone":           "+7 999 123-45-67",
		"website":         "shelter-test.ru",
		"description":     "Обновлённое описание",
		"longDescription": "Длинное описание",
		"tags":            []string{"обновлено"},
		"needs":           []string{"корма"},
	})
	assert.Equal(t, 200, resp.StatusCode)
	resp.Body.Close()
}

func TestShelters_Delete(t *testing.T) {
	require.NotEmpty(t, testShelterID)
	resp := doAuthJSON(t, "DELETE", "/v1/shelters/"+testShelterID, nil)
	assert.Equal(t, 204, resp.StatusCode)
	resp.Body.Close()
}

// ──────────────────────── Chats ────────────────────────

var testChatID string

func TestChats_Create(t *testing.T) {
	resp := doAuthJSON(t, "POST", "/v1/chats", map[string]string{
		"title": "CI чат",
	})
	assert.Equal(t, 201, resp.StatusCode)

	body := readBody(t, resp)
	require.NotEmpty(t, body["id"])
	testChatID = body["id"].(string)
}

func TestChats_List(t *testing.T) {
	resp := doAuthJSON(t, "GET", "/v1/chats", nil)
	assert.Equal(t, 200, resp.StatusCode)

	arr := readArray(t, resp)
	assert.GreaterOrEqual(t, len(arr), 1)
}

func TestChats_SendMessage(t *testing.T) {
	require.NotEmpty(t, testChatID)
	resp := doAuthJSON(t, "POST", "/v1/chats/"+testChatID+"/messages", map[string]string{
		"text": "Чем кормить котёнка?",
	})
	assert.Equal(t, 200, resp.StatusCode)

	body := readBody(t, resp)
	assert.Equal(t, "assistant", body["role"])
	assert.NotEmpty(t, body["content"])
}

func TestChats_GetMessages(t *testing.T) {
	require.NotEmpty(t, testChatID)
	resp := doAuthJSON(t, "GET", "/v1/chats/"+testChatID+"/messages", nil)
	assert.Equal(t, 200, resp.StatusCode)

	arr := readArray(t, resp)
	assert.GreaterOrEqual(t, len(arr), 2) // user + assistant
}

func TestChats_Delete(t *testing.T) {
	require.NotEmpty(t, testChatID)
	resp := doAuthJSON(t, "DELETE", "/v1/chats/"+testChatID, nil)
	assert.Equal(t, 204, resp.StatusCode)
	resp.Body.Close()
}

// ──────────────────────── 404 / Not Found ────────────────────────

func TestNotFound_Pet(t *testing.T) {
	resp := doAuthJSON(t, "GET", "/v1/pets/00000000-0000-0000-0000-000000000000", nil)
	assert.Equal(t, 404, resp.StatusCode)
	resp.Body.Close()
}

func TestNotFound_Shelter(t *testing.T) {
	resp := doAuthJSON(t, "GET", "/v1/shelters/00000000-0000-0000-0000-000000000000", nil)
	assert.Equal(t, 404, resp.StatusCode)
	resp.Body.Close()
}

// ──────────────────────── Unauthorized ────────────────────────

func TestUnauthorized(t *testing.T) {
	resp := doJSON(t, "GET", "/v1/profile", nil)
	assert.Equal(t, 401, resp.StatusCode)
	resp.Body.Close()
}
