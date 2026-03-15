// backend/internal/service/chat.go
package service

import (
	"context"
	"fmt"
	"log"
	"petio/backend/internal/metrics"
	"strings"
	"time"

	"petio/backend/clients/yandexai"
	"petio/backend/internal/domain"
	"petio/backend/internal/repository/postgres"
)

type ChatService struct {
	aiClient *yandexai.Client
	chatRepo *postgres.ChatRepository
}

func NewChatService(aiClient *yandexai.Client, chatRepo *postgres.ChatRepository) *ChatService {
	return &ChatService{
		aiClient: aiClient,
		chatRepo: chatRepo,
	}
}

const (
	DefaultContextSize = 10 // последние 10 сообщений для контекста
	MaxTitleLength     = 100
)

// CreateChat создает новый чат
func (s *ChatService) CreateChat(ctx context.Context, userID, title string) (*domain.Chat, error) {
	if title == "" {
		title = "Новый чат"
	}
	if len(title) > MaxTitleLength {
		title = title[:MaxTitleLength]
	}
	chat, err := s.chatRepo.CreateChat(ctx, userID, title)
	if err == nil {
		// Обновляем gauge активных чатов
		s.updateActiveChatGauge(ctx, userID)
	}
	return chat, err
}

// ListChats возвращает список чатов пользователя
func (s *ChatService) ListChats(ctx context.Context, userID string, limit, offset int) ([]domain.Chat, error) {
	return s.chatRepo.ListChats(ctx, userID, limit, offset)
}

// GetChat возвращает чат по ID
func (s *ChatService) GetChat(ctx context.Context, chatID, userID string) (*domain.Chat, error) {
	return s.chatRepo.GetChatByID(ctx, chatID, userID)
}

// GetMessages возвращает историю сообщений
func (s *ChatService) GetMessages(ctx context.Context, chatID string, limit, offset int) ([]domain.ChatMessage, error) {
	return s.chatRepo.GetMessages(ctx, chatID, limit, offset)
}

// DeleteChat удаляет чат
func (s *ChatService) DeleteChat(ctx context.Context, chatID, userID string) error {
	err := s.chatRepo.DeleteChat(ctx, chatID, userID)
	if err == nil {
		s.updateActiveChatGauge(ctx, userID)
	}
	return err
}

// UpdateChatTitle обновляет название чата
func (s *ChatService) UpdateChatTitle(ctx context.Context, chatID, userID, title string) error {
	if len(title) > MaxTitleLength {
		title = title[:MaxTitleLength]
	}
	return s.chatRepo.UpdateChatTitle(ctx, chatID, userID, title)
}

// SendMessage отправляет сообщение и получает ответ от AI
func (s *ChatService) SendMessage(ctx context.Context, chatID, userID, text string) (*domain.ChatMessage, error) {
	// Проверяем, что чат принадлежит пользователю
	chat, err := s.chatRepo.GetChatByID(ctx, chatID, userID)
	if err != nil {
		return nil, err
	}
	if chat == nil {
		return nil, fmt.Errorf("chat not found")
	}

	// Метрика: user message
	metrics.ChatMessagesTotal.WithLabelValues("user").Inc()

	// Сохраняем сообщение пользователя
	userMsg := &domain.ChatMessage{
		ChatID:    chatID,
		Role:      "user",
		Content:   text,
		CreatedAt: time.Now(),
	}
	if err := s.chatRepo.AddMessage(ctx, userMsg); err != nil {
		return nil, fmt.Errorf("save user message: %w", err)
	}

	// Получаем контекст (последние N сообщений)
	context, err := s.chatRepo.GetContext(ctx, chatID, DefaultContextSize)
	if err != nil {
		log.Printf("WARN: failed to load context: %v", err)
		context = []domain.ChatMessage{*userMsg}
	}

	// Получаем ответ от AI
	assistantMsg, err := s.getAIResponse(ctx, chatID, text, context)
	if err != nil {
		log.Printf("ERROR: AI response failed: %v", err)
		// Fallback
		metrics.AIRequestsTotal.WithLabelValues("fallback", "", "fallback").Inc()
		assistantMsg = s.fallbackMessage(chatID, text)
	}

	// Метрика: assistant message
	metrics.ChatMessagesTotal.WithLabelValues("assistant").Inc()

	// Сохраняем ответ ассистента
	if err := s.chatRepo.AddMessage(ctx, assistantMsg); err != nil {
		return nil, fmt.Errorf("save assistant message: %w", err)
	}

	// Автоматически генерируем заголовок для первого сообщения
	if chat.Title == "Новый чат" {
		title := s.generateTitle(text)
		_ = s.chatRepo.UpdateChatTitle(ctx, chatID, userID, title)
	}

	return assistantMsg, nil
}

func (s *ChatService) getAIResponse(ctx context.Context, chatID, text string, context []domain.ChatMessage) (*domain.ChatMessage, error) {
	if s.aiClient == nil {
		return s.fallbackMessage(chatID, text), nil
	}

	// 1. Классифицируем вопрос
	questionType, classifierUsage, err := s.aiClient.ClassifyQuestion(ctx, text)
	if err != nil {
		return nil, fmt.Errorf("classify: %w", err)
	}

	questionType = strings.TrimSpace(strings.ToLower(questionType))
	log.Printf("Question classified as: %s (tokens: %d in, %d out)",
		questionType, classifierUsage.InputTokens, classifierUsage.OutputTokens)

	// 2. Обрабатываем spam отдельно
	if questionType == "spam" {
		return &domain.ChatMessage{
			ChatID:       chatID,
			Role:         "assistant",
			Content:      "К сожалению, этот вопрос не относится к теме, в которой я разбираюсь. Я помогаю с уходом за домашними животными.",
			ModelUsed:    "classifier_only",
			QuestionType: questionType,
			InputTokens:  classifierUsage.InputTokens,
			OutputTokens: classifierUsage.OutputTokens,
			TotalTokens:  classifierUsage.TotalTokens,
			CreatedAt:    time.Now(),
		}, nil
	}

	// 3. Выбираем модель
	var answer string
	var usage *yandexai.Usage
	var modelUsed string

	switch questionType {
	case "simple":
		answer, usage, err = s.aiClient.GetSimpleAnswer(ctx, text)
		modelUsed = "light_model"
	default:
		answer, usage, err = s.aiClient.GetComplexAnswer(ctx, text)
		modelUsed = "big_model"
	}

	if err != nil {
		return nil, fmt.Errorf("ai model: %w", err)
	}

	// 4. Суммируем токены
	return &domain.ChatMessage{
		ChatID:       chatID,
		Role:         "assistant",
		Content:      answer,
		ModelUsed:    modelUsed,
		QuestionType: questionType,
		InputTokens:  classifierUsage.InputTokens + usage.InputTokens,
		OutputTokens: classifierUsage.OutputTokens + usage.OutputTokens,
		TotalTokens:  classifierUsage.TotalTokens + usage.TotalTokens,
		CreatedAt:    time.Now(),
	}, nil
}

func (s *ChatService) fallbackMessage(chatID, text string) *domain.ChatMessage {
	lower := strings.ToLower(text)
	var reply string

	if strings.Contains(lower, "корм") || strings.Contains(lower, "питани") {
		reply = "Питание — важнейший аспект здоровья вашего питомца! Основные правила: качественный корм по возрасту и виду, режим кормления, чистая вода."
	} else if strings.Contains(lower, "прививк") || strings.Contains(lower, "вакцин") {
		reply = "Схема вакцинации: собаки и кошки — первая прививка в 8–9 нед, ревакцинация в 12 нед, далее ежегодно. Обработка от глистов за 10–14 дней до прививки."
	} else if strings.Contains(lower, "лоток") || strings.Contains(lower, "туалет") {
		reply = "Приучение к лотку: лоток в тихое место, после еды и сна — в лоток, хвалите за успех, держите лоток чистым."
	} else {
		reply = "Могу посоветовать по кормлению, вакцинации, грумингу и поведению. Задайте конкретный вопрос."
	}

	return &domain.ChatMessage{
		ChatID:    chatID,
		Role:      "assistant",
		Content:   reply,
		ModelUsed: "fallback",
		CreatedAt: time.Now(),
	}
}

func (s *ChatService) generateTitle(firstMessage string) string {
	words := strings.Fields(firstMessage)
	if len(words) == 0 {
		return "Новый чат"
	}

	title := strings.Join(words, " ")
	if len(title) > 50 {
		title = title[:47] + "..."
	}
	return title
}

// GetStats возвращает общую статистику по чатам пользователя
func (s *ChatService) GetStats(ctx context.Context, userID string) (*domain.ChatStats, error) {
	return s.chatRepo.GetGlobalStats(ctx, userID)
}

func (s *ChatService) updateActiveChatGauge(ctx context.Context, userID string) {
	chats, err := s.chatRepo.ListChats(ctx, userID, 1000, 0)
	if err == nil {
		metrics.ActiveChatsGauge.Set(float64(len(chats)))
	}
}
