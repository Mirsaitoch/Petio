package yandexai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"petio/backend/internal/metrics"
	"time"
)

type Client struct {
	apiKey   string
	folderID string
	baseURL  string
	client   *http.Client
	// Метрики
	metrics *Metrics
}

type Config struct {
	APIKey   string
	FolderID string
	BaseURL  string
}

func New(cfg Config) *Client {
	if cfg.BaseURL == "" {
		cfg.BaseURL = "https://ai.api.cloud.yandex.net/v1"
	}
	return &Client{
		apiKey:   cfg.APIKey,
		folderID: cfg.FolderID,
		baseURL:  cfg.BaseURL,
		client:   &http.Client{Timeout: 60 * time.Second},
		metrics:  NewMetrics(),
	}
}

type Prompt struct {
	ID        string            `json:"id"`
	Variables map[string]string `json:"variables,omitempty"`
}

type ResponseRequest struct {
	Prompt Prompt `json:"prompt"`
	Input  string `json:"input"`
}

type ResponseData struct {
	ID       string `json:"id"`
	Model    string `json:"model"`
	Status   string `json:"status"`
	Output   Output `json:"output"`
	Usage    Usage  `json:"usage"`
	Settings struct {
		Temperature     float64 `json:"temperature"`
		TopP            float64 `json:"top_p"`
		MaxOutputTokens int     `json:"max_output_tokens"`
	} `json:"settings"`
}

type Output struct {
	Role   string `json:"role"`
	Status string `json:"status"`
	Text   string `json:"text"`
}

type Usage struct {
	InputTokens  int `json:"input_tokens"`
	OutputTokens int `json:"output_tokens"`
	TotalTokens  int `json:"total_tokens"`
}

// GetSimpleAnswer - легкая модель для простых вопросов
func (c *Client) GetSimpleAnswer(ctx context.Context, text string) (string, *Usage, error) {
	start := time.Now()
	promptID := "fvt232dfb6v0g086p7eq"

	resp, err := c.sendRequest(ctx, promptID, text, nil)
	duration := time.Since(start).Seconds()

	status := "success"
	if err != nil {
		status = "error"
	}

	metrics.AIRequestsTotal.WithLabelValues("light_model", "", status).Inc()
	metrics.AIRequestDuration.WithLabelValues("light_model").Observe(duration)

	if err != nil {
		return "", nil, err
	}

	c.recordTokenMetrics("light_model", resp.Usage)

	return resp.Output.Text, &resp.Usage, nil
}

func (c *Client) sendRequest(ctx context.Context, promptID string, input string, variables map[string]string) (*ResponseData, error) {
	reqData := ResponseRequest{
		Prompt: Prompt{
			ID:        promptID,
			Variables: variables,
		},
		Input: input,
	}

	jsonData, err := json.Marshal(reqData)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	url := c.baseURL + "/responses"
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Api-Key "+c.apiKey)
	req.Header.Set("OpenAI-Project", c.folderID)

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("do request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("yandex ai error %d: %s", resp.StatusCode, string(body))
	}

	var result ResponseData
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("unmarshal response: %w", err)
	}

	return &result, nil
}

// GetMetrics возвращает текущие метрики
func (c *Client) GetMetrics() MetricsSummary {
	return c.metrics.GetSummary()
}

func (c *Client) ClassifyQuestion(ctx context.Context, text string) (string, *Usage, error) {
	start := time.Now()
	promptID := "fvtvtokskb5o8r21de70"

	resp, err := c.sendRequest(ctx, promptID, text, nil)
	duration := time.Since(start).Seconds()

	// Метрики
	status := "success"
	if err != nil {
		status = "error"
	}

	metrics.AIRequestsTotal.WithLabelValues("classifier", "", status).Inc()
	metrics.AIRequestDuration.WithLabelValues("classifier").Observe(duration)

	if err != nil {
		return "", nil, err
	}

	// Записываем токены
	c.recordTokenMetrics("classifier", resp.Usage)

	return resp.Output.Text, &resp.Usage, nil
}

func (c *Client) GetComplexAnswer(ctx context.Context, text string) (string, *Usage, error) {
	start := time.Now()
	promptID := "fvt14l2e6cj5p7t18d4g"

	resp, err := c.sendRequest(ctx, promptID, text, nil)
	duration := time.Since(start).Seconds()

	status := "success"
	if err != nil {
		status = "error"
	}

	metrics.AIRequestsTotal.WithLabelValues("big_model", "", status).Inc()
	metrics.AIRequestDuration.WithLabelValues("big_model").Observe(duration)

	if err != nil {
		return "", nil, err
	}

	c.recordTokenMetrics("big_model", resp.Usage)

	return resp.Output.Text, &resp.Usage, nil
}

func (c *Client) recordTokenMetrics(model string, usage Usage) {
	metrics.AIInputTokensTotal.WithLabelValues(model).Add(float64(usage.InputTokens))
	metrics.AIOutputTokensTotal.WithLabelValues(model).Add(float64(usage.OutputTokens))
	metrics.AITokensTotal.WithLabelValues(model).Add(float64(usage.TotalTokens))

	metrics.AITokensHistogram.WithLabelValues(model, "input").Observe(float64(usage.InputTokens))
	metrics.AITokensHistogram.WithLabelValues(model, "output").Observe(float64(usage.OutputTokens))

	// Записываем в in-memory метрики (для старого API /chat/metrics)
	c.metrics.RecordUsage(model, usage.InputTokens, usage.OutputTokens)
}
