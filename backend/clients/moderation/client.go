package moderation

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/textproto"
	"petio/backend/internal/metrics"
	"time"
)

type Client struct {
	baseURL    string
	httpClient *http.Client
}

func New(baseURL string) *Client {
	if baseURL == "" {
		return nil
	}
	return &Client{
		baseURL:    baseURL,
		httpClient: &http.Client{Timeout: 30 * time.Second},
	}
}

// --- Text ---

type TextScores struct {
	Toxicity       float64 `json:"toxicity"`
	SevereToxicity float64 `json:"severe_toxicity"`
	Obscene        float64 `json:"obscene"`
	Threat         float64 `json:"threat"`
	Insult         float64 `json:"insult"`
	IdentityAttack float64 `json:"identity_attack"`
	SexualExplicit float64 `json:"sexual_explicit"`
}

// TextResponse — полный ответ moderation_service /texts_scores
type TextResponse struct {
	Action      string     `json:"action"`
	Blocked     bool       `json:"blocked"`
	NeedsReview bool       `json:"needs_review"`
	Reason      *string    `json:"reason"`
	Confidence  float64    `json:"confidence"`
	Scores      TextScores `json:"scores"`
}

// ImageScores — вложенный объект scores из ответа moderation_service
type ImageScores struct {
	NSFW     float64 `json:"nsfw"`
	Safe     float64 `json:"safe"`
	Medical  float64 `json:"medical"`
	Porn     float64 `json:"porn"`
	Violence float64 `json:"violence"`
	Abuse    float64 `json:"abuse"`
}

// ImageResponse соответствует ответу moderation_service /images_scores
type ImageResponse struct {
	Action      string      `json:"action"`
	Blocked     bool        `json:"blocked"`
	NeedsReview bool        `json:"needs_review"`
	Reason      *string     `json:"reason"`
	Confidence  float64     `json:"confidence"`
	Scores      ImageScores `json:"scores"`
}

func (c *Client) CheckText(ctx context.Context, text string) (*TextResponse, error) {
	if c == nil {
		return nil, nil
	}

	start := time.Now()
	body, err := json.Marshal(map[string]string{"text": text})
	if err != nil {
		return nil, fmt.Errorf("moderation: marshal: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/texts_scores", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("moderation: request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	duration := time.Since(start).Seconds()

	if err != nil {
		metrics.ModerationRequestsTotal.WithLabelValues("text", "error").Inc()
		return nil, fmt.Errorf("moderation: do: %w", err)
	}
	defer resp.Body.Close()

	metrics.ModerationDuration.WithLabelValues("text").Observe(duration)

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		metrics.ModerationRequestsTotal.WithLabelValues("text", "error").Inc()
		return nil, fmt.Errorf("moderation: %d: %s", resp.StatusCode, string(b))
	}

	var result TextResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("moderation: decode: %w", err)
	}

	action := "pass"
	if result.Blocked {
		action = "block"
		reason := "unknown"
		if result.Reason != nil {
			reason = *result.Reason
		}
		metrics.ModerationBlockedTotal.WithLabelValues("text", reason).Inc()
	}
	metrics.ModerationRequestsTotal.WithLabelValues("text", action).Inc()

	return &result, nil
}

// --- Image ---

func detectImageContentType(data []byte) string {
	ct := http.DetectContentType(data)
	if ct == "application/octet-stream" {
		return "image/jpeg"
	}
	return ct
}

func (c *Client) CheckImage(ctx context.Context, imageBytes []byte, filename string) (*ImageResponse, error) {
	if c == nil {
		return nil, nil
	}

	start := time.Now()
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)

	partHeader := make(textproto.MIMEHeader)
	partHeader.Set("Content-Disposition",
		fmt.Sprintf(`form-data; name="image"; filename="%s"`, filename))
	partHeader.Set("Content-Type", detectImageContentType(imageBytes))

	part, err := w.CreatePart(partHeader)
	if err != nil {
		return nil, fmt.Errorf("moderation: form: %w", err)
	}
	if _, err := part.Write(imageBytes); err != nil {
		return nil, fmt.Errorf("moderation: write: %w", err)
	}
	w.Close()

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/images_scores", &buf)
	if err != nil {
		return nil, fmt.Errorf("moderation: request: %w", err)
	}
	req.Header.Set("Content-Type", w.FormDataContentType())

	resp, err := c.httpClient.Do(req)
	duration := time.Since(start).Seconds()

	if err != nil {
		metrics.ModerationRequestsTotal.WithLabelValues("image", "error").Inc()
		return nil, fmt.Errorf("moderation: do: %w", err)
	}
	defer resp.Body.Close()

	metrics.ModerationDuration.WithLabelValues("image").Observe(duration)

	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		metrics.ModerationRequestsTotal.WithLabelValues("image", "error").Inc()
		return nil, fmt.Errorf("moderation: %d: %s", resp.StatusCode, string(b))
	}

	var result ImageResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("moderation: decode: %w", err)
	}

	action := "pass"
	if result.Blocked {
		action = "block"
	}
	metrics.ModerationRequestsTotal.WithLabelValues("image", action).Inc()
	if result.Blocked {
		reason := "unknown"
		if result.Reason != nil {
			reason = *result.Reason
		}
		metrics.ModerationBlockedTotal.WithLabelValues("image", reason).Inc()
	}

	return &result, nil
}
