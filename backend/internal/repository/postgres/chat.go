// backend/internal/repository/postgres/chat.go
package postgres

import (
	"context"
	"database/sql"
	"time"

	"github.com/google/uuid"

	"petio/backend/internal/domain"
)

type ChatRepository struct {
	db *sql.DB
}

func NewChatRepository(db *sql.DB) *ChatRepository {
	return &ChatRepository{db: db}
}

// ========== CHATS ==========

func (r *ChatRepository) CreateChat(ctx context.Context, userID, title string) (*domain.Chat, error) {
	chat := &domain.Chat{
		ID:        uuid.New().String(),
		UserID:    userID,
		Title:     title,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	_, err := r.db.ExecContext(ctx,
		`INSERT INTO chats (id, user_id, title, created_at, updated_at) VALUES ($1, $2, $3, $4, $5)`,
		chat.ID, chat.UserID, chat.Title, chat.CreatedAt, chat.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	// Создаем запись статистики
	_, _ = r.db.ExecContext(ctx,
		`INSERT INTO chat_stats (chat_id) VALUES ($1)`,
		chat.ID,
	)

	return chat, nil
}

func (r *ChatRepository) GetChatByID(ctx context.Context, chatID, userID string) (*domain.Chat, error) {
	var chat domain.Chat
	err := r.db.QueryRowContext(ctx,
		`SELECT id, user_id, title, created_at, updated_at FROM chats WHERE id = $1 AND user_id = $2`,
		chatID, userID,
	).Scan(&chat.ID, &chat.UserID, &chat.Title, &chat.CreatedAt, &chat.UpdatedAt)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	// Загружаем статистику
	chat.Stats, _ = r.GetChatStats(ctx, chatID)

	return &chat, nil
}

func (r *ChatRepository) ListChats(ctx context.Context, userID string, limit, offset int) ([]domain.Chat, error) {
	if limit <= 0 {
		limit = 20
	}

	rows, err := r.db.QueryContext(ctx,
		`SELECT id, user_id, title, created_at, updated_at 
		 FROM chats 
		 WHERE user_id = $1 
		 ORDER BY updated_at DESC 
		 LIMIT $2 OFFSET $3`,
		userID, limit, offset,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var chats []domain.Chat
	for rows.Next() {
		var chat domain.Chat
		if err := rows.Scan(&chat.ID, &chat.UserID, &chat.Title, &chat.CreatedAt, &chat.UpdatedAt); err != nil {
			return nil, err
		}

		// Загружаем последнее сообщение
		chat.LastMessage, _ = r.GetLastMessage(ctx, chat.ID)
		chat.Stats, _ = r.GetChatStats(ctx, chat.ID)

		chats = append(chats, chat)
	}

	return chats, rows.Err()
}

func (r *ChatRepository) UpdateChatTitle(ctx context.Context, chatID, userID, title string) error {
	res, err := r.db.ExecContext(ctx,
		`UPDATE chats SET title = $1, updated_at = $2 WHERE id = $3 AND user_id = $4`,
		title, time.Now(), chatID, userID,
	)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *ChatRepository) DeleteChat(ctx context.Context, chatID, userID string) error {
	res, err := r.db.ExecContext(ctx,
		`DELETE FROM chats WHERE id = $1 AND user_id = $2`,
		chatID, userID,
	)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

// ========== MESSAGES ==========

func (r *ChatRepository) AddMessage(ctx context.Context, msg *domain.ChatMessage) error {
	if msg.ID == "" {
		msg.ID = uuid.New().String()
	}
	if msg.CreatedAt.IsZero() {
		msg.CreatedAt = time.Now()
	}

	_, err := r.db.ExecContext(ctx,
		`INSERT INTO chat_messages 
		 (id, chat_id, role, content, model_used, question_type, input_tokens, output_tokens, total_tokens, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		msg.ID, msg.ChatID, msg.Role, msg.Content,
		msg.ModelUsed, msg.QuestionType,
		msg.InputTokens, msg.OutputTokens, msg.TotalTokens,
		msg.CreatedAt,
	)
	if err != nil {
		return err
	}

	// Обновляем updated_at чата
	_, _ = r.db.ExecContext(ctx,
		`UPDATE chats SET updated_at = $1 WHERE id = $2`,
		msg.CreatedAt, msg.ChatID,
	)

	// Обновляем статистику
	r.updateChatStats(ctx, msg)

	return nil
}

func (r *ChatRepository) GetMessages(ctx context.Context, chatID string, limit, offset int) ([]domain.ChatMessage, error) {
	if limit <= 0 {
		limit = 50
	}

	rows, err := r.db.QueryContext(ctx,
		`SELECT id, chat_id, role, content, model_used, question_type, 
		        input_tokens, output_tokens, total_tokens, created_at
		 FROM chat_messages
		 WHERE chat_id = $1
		 ORDER BY created_at ASC
		 LIMIT $2 OFFSET $3`,
		chatID, limit, offset,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []domain.ChatMessage
	for rows.Next() {
		var msg domain.ChatMessage
		var modelUsed, questionType sql.NullString

		if err := rows.Scan(
			&msg.ID, &msg.ChatID, &msg.Role, &msg.Content,
			&modelUsed, &questionType,
			&msg.InputTokens, &msg.OutputTokens, &msg.TotalTokens,
			&msg.CreatedAt,
		); err != nil {
			return nil, err
		}

		if modelUsed.Valid {
			msg.ModelUsed = modelUsed.String
		}
		if questionType.Valid {
			msg.QuestionType = questionType.String
		}

		messages = append(messages, msg)
	}

	return messages, rows.Err()
}

func (r *ChatRepository) GetLastMessage(ctx context.Context, chatID string) (*domain.ChatMessage, error) {
	var msg domain.ChatMessage
	var modelUsed, questionType sql.NullString

	err := r.db.QueryRowContext(ctx,
		`SELECT id, chat_id, role, content, model_used, question_type, 
		        input_tokens, output_tokens, total_tokens, created_at
		 FROM chat_messages
		 WHERE chat_id = $1
		 ORDER BY created_at DESC
		 LIMIT 1`,
		chatID,
	).Scan(
		&msg.ID, &msg.ChatID, &msg.Role, &msg.Content,
		&modelUsed, &questionType,
		&msg.InputTokens, &msg.OutputTokens, &msg.TotalTokens,
		&msg.CreatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	if modelUsed.Valid {
		msg.ModelUsed = modelUsed.String
	}
	if questionType.Valid {
		msg.QuestionType = questionType.String
	}

	return &msg, nil
}

// GetContext возвращает последние N сообщений для контекста AI
func (r *ChatRepository) GetContext(ctx context.Context, chatID string, contextSize int) ([]domain.ChatMessage, error) {
	if contextSize <= 0 {
		contextSize = 10
	}

	rows, err := r.db.QueryContext(ctx,
		`SELECT id, chat_id, role, content, created_at
		 FROM chat_messages
		 WHERE chat_id = $1
		 ORDER BY created_at DESC
		 LIMIT $2`,
		chatID, contextSize,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []domain.ChatMessage
	for rows.Next() {
		var msg domain.ChatMessage
		if err := rows.Scan(&msg.ID, &msg.ChatID, &msg.Role, &msg.Content, &msg.CreatedAt); err != nil {
			return nil, err
		}
		messages = append(messages, msg)
	}

	// Разворачиваем, чтобы старые сообщения были первыми
	for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
		messages[i], messages[j] = messages[j], messages[i]
	}

	return messages, rows.Err()
}

// ========== STATS ==========

func (r *ChatRepository) GetChatStats(ctx context.Context, chatID string) (*domain.ChatStats, error) {
	var stats domain.ChatStats
	err := r.db.QueryRowContext(ctx,
		`SELECT chat_id, message_count, total_input_tokens, total_output_tokens, total_tokens, last_message_at
		 FROM chat_stats WHERE chat_id = $1`,
		chatID,
	).Scan(&stats.ChatID, &stats.MessageCount, &stats.TotalInputTokens, &stats.TotalOutputTokens, &stats.TotalTokens, &stats.LastMessageAt)

	if err == sql.ErrNoRows {
		return &domain.ChatStats{ChatID: chatID}, nil
	}
	if err != nil {
		return nil, err
	}

	return &stats, nil
}

func (r *ChatRepository) updateChatStats(ctx context.Context, msg *domain.ChatMessage) {
	_, _ = r.db.ExecContext(ctx,
		`INSERT INTO chat_stats (chat_id, message_count, total_input_tokens, total_output_tokens, total_tokens, last_message_at)
		 VALUES ($1, 1, $2, $3, $4, $5)
		 ON CONFLICT (chat_id) DO UPDATE SET
		   message_count = chat_stats.message_count + 1,
		   total_input_tokens = chat_stats.total_input_tokens + $2,
		   total_output_tokens = chat_stats.total_output_tokens + $3,
		   total_tokens = chat_stats.total_tokens + $4,
		   last_message_at = $5`,
		msg.ChatID, msg.InputTokens, msg.OutputTokens, msg.TotalTokens, msg.CreatedAt,
	)
}

// GetGlobalStats возвращает общую статистику по всем чатам пользователя
func (r *ChatRepository) GetGlobalStats(ctx context.Context, userID string) (*domain.ChatStats, error) {
	var stats domain.ChatStats
	err := r.db.QueryRowContext(ctx,
		`SELECT 
		   COALESCE(SUM(cs.message_count), 0) as message_count,
		   COALESCE(SUM(cs.total_input_tokens), 0) as total_input_tokens,
		   COALESCE(SUM(cs.total_output_tokens), 0) as total_output_tokens,
		   COALESCE(SUM(cs.total_tokens), 0) as total_tokens
		 FROM chat_stats cs
		 JOIN chats c ON c.id = cs.chat_id
		 WHERE c.user_id = $1`,
		userID,
	).Scan(&stats.MessageCount, &stats.TotalInputTokens, &stats.TotalOutputTokens, &stats.TotalTokens)

	if err != nil {
		return nil, err
	}

	return &stats, nil
}
