package yandexai

import (
	"sync"
	"time"
)

type Metrics struct {
	mu     sync.RWMutex
	models map[string]*ModelMetrics
}

type ModelMetrics struct {
	TotalRequests     int64
	TotalInputTokens  int64
	TotalOutputTokens int64
	TotalTokens       int64
	LastUsedAt        time.Time
}

type MetricsSummary struct {
	Models map[string]ModelMetrics `json:"models"`
	Total  ModelMetrics            `json:"total"`
}

func NewMetrics() *Metrics {
	return &Metrics{
		models: make(map[string]*ModelMetrics),
	}
}

func (m *Metrics) RecordUsage(modelName string, inputTokens, outputTokens int) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, exists := m.models[modelName]; !exists {
		m.models[modelName] = &ModelMetrics{}
	}

	metrics := m.models[modelName]
	metrics.TotalRequests++
	metrics.TotalInputTokens += int64(inputTokens)
	metrics.TotalOutputTokens += int64(outputTokens)
	metrics.TotalTokens += int64(inputTokens + outputTokens)
	metrics.LastUsedAt = time.Now()
}

func (m *Metrics) GetSummary() MetricsSummary {
	m.mu.RLock()
	defer m.mu.RUnlock()

	summary := MetricsSummary{
		Models: make(map[string]ModelMetrics),
	}

	for name, metrics := range m.models {
		summary.Models[name] = *metrics

		// Суммируем в total
		summary.Total.TotalRequests += metrics.TotalRequests
		summary.Total.TotalInputTokens += metrics.TotalInputTokens
		summary.Total.TotalOutputTokens += metrics.TotalOutputTokens
		summary.Total.TotalTokens += metrics.TotalTokens
	}

	return summary
}

func (m *Metrics) Reset() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.models = make(map[string]*ModelMetrics)
}
