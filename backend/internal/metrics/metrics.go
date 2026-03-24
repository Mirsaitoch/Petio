// backend/internal/metrics/metrics.go
package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// ========== HTTP METRICS ==========

	// Количество HTTP запросов
	HTTPRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "endpoint", "status"},
	)

	// Длительность HTTP запросов
	HTTPRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "Duration of HTTP requests in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "endpoint", "status"},
	)

	// Размер ответов
	HTTPResponseSize = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_response_size_bytes",
			Help:    "Size of HTTP responses in bytes",
			Buckets: prometheus.ExponentialBuckets(100, 10, 8),
		},
		[]string{"method", "endpoint"},
	)

	// ========== AI CHAT METRICS ==========

	// Количество запросов к AI
	AIRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "ai_requests_total",
			Help: "Total number of AI requests",
		},
		[]string{"model", "question_type", "status"}, // status: success, error, fallback
	)

	// Длительность запросов к AI
	AIRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "ai_request_duration_seconds",
			Help:    "Duration of AI requests in seconds",
			Buckets: []float64{0.1, 0.5, 1, 2, 5, 10, 30},
		},
		[]string{"model"},
	)

	// Токены (input)
	AIInputTokensTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "ai_input_tokens_total",
			Help: "Total number of input tokens used",
		},
		[]string{"model"},
	)

	// Токены (output)
	AIOutputTokensTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "ai_output_tokens_total",
			Help: "Total number of output tokens generated",
		},
		[]string{"model"},
	)

	// Токены (total)
	AITokensTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "ai_tokens_total",
			Help: "Total number of tokens used",
		},
		[]string{"model"},
	)

	// Распределение токенов
	AITokensHistogram = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "ai_tokens_per_request",
			Help:    "Distribution of tokens per request",
			Buckets: []float64{10, 50, 100, 200, 500, 1000, 2000, 5000},
		},
		[]string{"model", "type"}, // type: input, output
	)

	// ========== CHAT METRICS ==========

	// Активные чаты
	ActiveChatsGauge = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "active_chats_total",
			Help: "Number of active chats",
		},
	)

	// Сообщения в чатах
	ChatMessagesTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "chat_messages_total",
			Help: "Total number of chat messages",
		},
		[]string{"role"}, // user, assistant, system
	)

	// Длина чатов (количество сообщений)
	ChatLengthHistogram = promauto.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "chat_length_messages",
			Help:    "Distribution of chat lengths in messages",
			Buckets: []float64{1, 5, 10, 20, 50, 100, 200},
		},
	)

	// ========== MODERATION METRICS ==========

	// Запросы к модерации
	ModerationRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "moderation_requests_total",
			Help: "Total number of moderation requests",
		},
		[]string{"type", "result"}, // type: text/image, result: pass/block
	)

	// Длительность модерации
	ModerationDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "moderation_duration_seconds",
			Help:    "Duration of moderation checks",
			Buckets: []float64{0.05, 0.1, 0.25, 0.5, 1, 2},
		},
		[]string{"type"},
	)

	// Заблокированный контент
	ModerationBlockedTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "moderation_blocked_total",
			Help: "Total number of blocked content",
		},
		[]string{"type", "reason"},
	)

	// ========== S3 METRICS ==========

	// Загрузки в S3
	S3UploadsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "s3_uploads_total",
			Help: "Total number of S3 uploads",
		},
		[]string{"type", "status"}, // type: pet-photo/post-image/avatar, status: success/error
	)

	// Размер загрузок
	S3UploadSize = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "s3_upload_size_bytes",
			Help:    "Size of S3 uploads in bytes",
			Buckets: prometheus.ExponentialBuckets(1024, 2, 15), // 1KB to 16MB
		},
		[]string{"type"},
	)

	// Длительность загрузок
	S3UploadDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "s3_upload_duration_seconds",
			Help:    "Duration of S3 uploads",
			Buckets: []float64{0.1, 0.5, 1, 2, 5, 10},
		},
		[]string{"type"},
	)

	// ========== DATABASE METRICS ==========

	// Запросы к БД
	DBQueriesTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "db_queries_total",
			Help: "Total number of database queries",
		},
		[]string{"operation", "table", "status"}, // operation: select/insert/update/delete
	)

	// Длительность запросов к БД
	DBQueryDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "db_query_duration_seconds",
			Help:    "Duration of database queries",
			Buckets: []float64{0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1},
		},
		[]string{"operation", "table"},
	)

	// ========== BUSINESS METRICS ==========

	// Регистрации пользователей
	UserRegistrationsTotal = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "user_registrations_total",
			Help: "Total number of user registrations",
		},
	)

	// Созданные питомцы
	PetsCreatedTotal = promauto.NewCounter(
		prometheus.CounterOpts{
			Name: "pets_created_total",
			Help: "Total number of pets created",
		},
	)

	// Посты в сообществе
	PostsCreatedTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "posts_created_total",
			Help: "Total number of posts created",
		},
		[]string{"club"},
	)
)
