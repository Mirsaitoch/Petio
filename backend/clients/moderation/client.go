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
	Toxic          float64 `json:"toxicity"`
	SevereToxic    float64 `json:"severe_toxicity"`
	Obscene        float64 `json:"obscene"`
	Threat         float64 `json:"threat"`
	Insult         float64 `json:"insult"`
	IdentityAttack float64 `json:"identity_attack"`
	SexualExplicit float64 `json:"sexual_explicit"`
}

func (c *Client) CheckText(ctx context.Context, text string) (*TextScores, error) {
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

	var scores TextScores
	if err := json.NewDecoder(resp.Body).Decode(&scores); err != nil {
		return nil, fmt.Errorf("moderation: decode: %w", err)
	}

	// Определяем результат
	result := "pass"
	if scores.Toxic > 0.8 || scores.Obscene > 0.8 || scores.Threat > 0.8 {
		result = "block"
		reason := "toxic"
		if scores.Obscene > scores.Toxic {
			reason = "obscene"
		}
		if scores.Threat > scores.Obscene && scores.Threat > scores.Toxic {
			reason = "threat"
		}
		metrics.ModerationBlockedTotal.WithLabelValues("text", reason).Inc()
	}

	metrics.ModerationRequestsTotal.WithLabelValues("text", result).Inc()

	return &scores, nil
}

// --- Image ---

type ImageScores struct {
	NSFWScore     float64 `json:"nsfw_score"`
	PornScore     float64 `json:"porn_score"`
	ViolenceScore float64 `json:"violence_score"`
	AbuseScore    float64 `json:"abuse_score"`
	Block         bool    `json:"block"`
	Reason        *string `json:"reason"`
}

func detectImageContentType(data []byte) string {
	ct := http.DetectContentType(data)
	if ct == "application/octet-stream" {
		return "image/jpeg"
	}
	return ct
}

func (c *Client) CheckImage(ctx context.Context, imageBytes []byte, filename string) (*ImageScores, error) {
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

	var scores ImageScores
	if err := json.NewDecoder(resp.Body).Decode(&scores); err != nil {
		return nil, fmt.Errorf("moderation: decode: %w", err)
	}

	result := "pass"
	if scores.Block {
		result = "block"
		reason := "nsfw"
		if scores.Reason != nil {
			reason = *scores.Reason
		}
		metrics.ModerationBlockedTotal.WithLabelValues("image", reason).Inc()
	}

	metrics.ModerationRequestsTotal.WithLabelValues("image", result).Inc()

	return &scores, nil
}
