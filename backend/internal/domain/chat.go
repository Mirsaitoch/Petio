// backend/internal/domain/chat.go
package domain

import "time"

type Chat struct {
	ID        string    `json:"id" db:"id"`
	UserID    string    `json:"user_id" db:"user_id"`
	Title     string    `json:"title" db:"title"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`

	// Не из БД - подгружаем отдельно
	LastMessage *ChatMessage `json:"last_message,omitempty" db:"-"`
	Stats       *ChatStats   `json:"stats,omitempty" db:"-"`
}

type ChatMessage struct {
	ID      string `json:"id" db:"id"`
	ChatID  string `json:"chat_id" db:"chat_id"`
	Role    string `json:"role" db:"role"` // user, assistant, system
	Content string `json:"content" db:"content"`

	// AI метаданные
	ModelUsed    string `json:"model_used,omitempty" db:"model_used"`
	QuestionType string `json:"question_type,omitempty" db:"question_type"`
	InputTokens  int    `json:"input_tokens,omitempty" db:"input_tokens"`
	OutputTokens int    `json:"output_tokens,omitempty" db:"output_tokens"`
	TotalTokens  int    `json:"total_tokens,omitempty" db:"total_tokens"`

	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

type ChatStats struct {
	ChatID            string     `json:"chat_id" db:"chat_id"`
	MessageCount      int        `json:"message_count" db:"message_count"`
	TotalInputTokens  int64      `json:"total_input_tokens" db:"total_input_tokens"`
	TotalOutputTokens int64      `json:"total_output_tokens" db:"total_output_tokens"`
	TotalTokens       int64      `json:"total_tokens" db:"total_tokens"`
	LastMessageAt     *time.Time `json:"last_message_at,omitempty" db:"last_message_at"`
}

type ChatContext struct {
	Messages []ChatMessage `json:"messages"`
}
