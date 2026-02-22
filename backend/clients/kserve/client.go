package kserve

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
)

type Client struct {
	baseURL    string
	httpClient *http.Client
}

func New(baseURL string) *Client {
	if baseURL == "" {
		return &Client{}
	}
	return &Client{
		baseURL:    baseURL,
		httpClient: &http.Client{},
	}
}

func (c *Client) Predict(ctx context.Context, modelName string, inputData []float32) ([]float32, error) {
	if c.baseURL == "" {
		return nil, nil
	}
	return c.infer(ctx, modelName, inputData)
}

func (c *Client) infer(ctx context.Context, modelName string, inputData []float32) ([]float32, error) {
	u, err := url.JoinPath(c.baseURL, "v2/models", modelName, "infer")
	if err != nil {
		return nil, fmt.Errorf("kserve url: %w", err)
	}
	reqBody := v2InferRequest{
		Inputs: []v2InferInput{
			{
				Name:     "input",
				Shape:    []int64{1, int64(len(inputData))},
				Datatype: "FP32",
				Data:     inputData,
			},
		},
	}
	body, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, u, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("kserve request: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("kserve %s: %s", resp.Status, string(b))
	}
	var out v2InferResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	if len(out.Outputs) == 0 {
		return nil, fmt.Errorf("kserve: no outputs")
	}
	return out.Outputs[0].Data, nil
}

type v2InferRequest struct {
	Inputs []v2InferInput `json:"inputs"`
}

type v2InferInput struct {
	Name     string    `json:"name"`
	Shape    []int64   `json:"shape"`
	Datatype string    `json:"datatype"`
	Data     []float32 `json:"data"`
}

type v2InferResponse struct {
	Outputs []v2InferOutput `json:"outputs"`
}

type v2InferOutput struct {
	Name     string    `json:"name"`
	Shape    []int64   `json:"shape"`
	Datatype string    `json:"datatype"`
	Data     []float32 `json:"data"`
}
