// backend/internal/service/chat.go
package service

import (
	"context"
	"fmt"
	"petio/backend/internal/logger"
	"petio/backend/internal/metrics"
	"strings"
	"time"

	"go.uber.org/zap"

	"petio/backend/clients/yandexai"
	"petio/backend/internal/domain"
	"petio/backend/internal/repository/postgres"
)

type ChatService struct {
	aiClient *yandexai.Client
	chatRepo *postgres.ChatRepository
	log      *zap.Logger
}

func NewChatService(aiClient *yandexai.Client, chatRepo *postgres.ChatRepository, log *zap.Logger) *ChatService {
	return &ChatService{
		aiClient: aiClient,
		chatRepo: chatRepo,
		log:      log,
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
		logger.FromCtx(ctx).Info("chat created",
			zap.String("chat_id", chat.ID),
			zap.String("title", title),
		)
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
		logger.FromCtx(ctx).Info("chat deleted", zap.String("chat_id", chatID))
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
	l := logger.FromCtx(ctx).With(zap.String("chat_id", chatID))

	// Проверяем, что чат принадлежит пользователю
	chat, err := s.chatRepo.GetChatByID(ctx, chatID, userID)
	if err != nil {
		return nil, err
	}
	if chat == nil {
		l.Warn("chat not found")
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
	chatContext, err := s.chatRepo.GetContext(ctx, chatID, DefaultContextSize)
	if err != nil {
		l.Warn("failed to load chat context", zap.Error(err))
		chatContext = []domain.ChatMessage{*userMsg}
	}

	// Получаем ответ от AI
	assistantMsg, err := s.getAIResponse(ctx, chatID, text, chatContext)
	if err != nil {
		l.Error("ai response failed, using fallback", zap.Error(err))
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

	l.Info("message processed",
		zap.String("model", assistantMsg.ModelUsed),
		zap.String("question_type", assistantMsg.QuestionType),
		zap.Int("input_tokens", assistantMsg.InputTokens),
		zap.Int("output_tokens", assistantMsg.OutputTokens),
	)

	return assistantMsg, nil
}

// classificationResult — результат парсинга ответа классификатора (две цифры: категория + необходимость контекста).
// Категории: 0 — простой, 1 — сложный, 2 — уточняющий, 3 — не про животных, 4 — благодарность.
// Контекст: 0 — не нужен, 1 — нужен.
type classificationResult struct {
	Category    int
	NeedContext bool
}

func parseClassification(raw string) classificationResult {
	s := strings.TrimSpace(raw)
	if len(s) < 2 {
		return classificationResult{Category: 1, NeedContext: true}
	}
	cat := int(s[0] - '0')
	ctx := s[1] == '1'
	if cat < 0 || cat > 4 {
		cat = 1
	}
	return classificationResult{Category: cat, NeedContext: ctx}
}

func categoryLabel(cat int) string {
	switch cat {
	case 0:
		return "simple"
	case 1:
		return "complex"
	case 2:
		return "clarification"
	case 3:
		return "off_topic"
	case 4:
		return "gratitude"
	default:
		return "unknown"
	}
}

func (s *ChatService) getAIResponse(ctx context.Context, chatID, text string, chatContext []domain.ChatMessage) (*domain.ChatMessage, error) {
	if s.aiClient == nil {
		return s.fallbackMessage(chatID, text), nil
	}

	l := logger.FromCtx(ctx).With(zap.String("chat_id", chatID))

	// 1. Классифицируем вопрос
	rawType, classifierUsage, err := s.aiClient.ClassifyQuestion(ctx, text)
	if err != nil {
		return nil, fmt.Errorf("classify: %w", err)
	}

	cl := parseClassification(rawType)
	questionType := categoryLabel(cl.Category)

	l.Info("question classified",
		zap.String("raw", strings.TrimSpace(rawType)),
		zap.String("type", questionType),
		zap.Bool("need_context", cl.NeedContext),
		zap.Int("classifier_input_tokens", classifierUsage.InputTokens),
		zap.Int("classifier_output_tokens", classifierUsage.OutputTokens),
	)

	// 2. Вопрос не по теме
	if cl.Category == 3 {
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

	// 3. Благодарность
	if cl.Category == 4 {
		return &domain.ChatMessage{
			ChatID:       chatID,
			Role:         "assistant",
			Content:      "Рад помочь! Если появятся ещё вопросы по уходу за питомцем — обращайтесь.",
			ModelUsed:    "classifier_only",
			QuestionType: questionType,
			InputTokens:  classifierUsage.InputTokens,
			OutputTokens: classifierUsage.OutputTokens,
			TotalTokens:  classifierUsage.TotalTokens,
			CreatedAt:    time.Now(),
		}, nil
	}

	// 4. Собираем контекст только если классификатор сказал, что он нужен
	var chatHistory string
	if cl.NeedContext {
		chatHistory = buildChatHistory(chatContext)
	}

	// 5. Выбираем модель: 0 — simple (light), 1/2 — complex (big)
	var answer string
	var usage *yandexai.Usage
	var modelUsed string

	switch cl.Category {
	case 0:
		answer, usage, err = s.aiClient.GetSimpleAnswer(ctx, text, chatHistory)
		modelUsed = "light_model"
	default: // 1, 2
		answer, usage, err = s.aiClient.GetComplexAnswer(ctx, text, chatHistory)
		modelUsed = "big_model"
	}

	if err != nil {
		return nil, fmt.Errorf("ai model: %w", err)
	}

	// 6. Суммируем токены
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

// buildChatHistory форматирует предыдущие сообщения в строку для передачи в промпт.
// Формат: "user: текст\nassistant: текст\n..."
// Последнее сообщение (текущий вопрос) не включается — оно идёт в input.
func buildChatHistory(messages []domain.ChatMessage) string {
	if len(messages) <= 1 {
		return ""
	}
	var b strings.Builder
	// Все кроме последнего (последнее = текущий вопрос пользователя)
	for _, m := range messages[:len(messages)-1] {
		b.WriteString(m.Role)
		b.WriteString(": ")
		b.WriteString(m.Content)
		b.WriteString("\n")
	}
	return b.String()
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
