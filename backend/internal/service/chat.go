package service

import (
	"context"
	"strings"

	"petio/backend/clients/kserve"
)

type ChatService struct {
	kserve *kserve.Client
}

func NewChatService(kc *kserve.Client) *ChatService {
	return &ChatService{kserve: kc}
}

func (s *ChatService) Send(ctx context.Context, text string) (string, error) {
	lower := strings.ToLower(text)
	if strings.Contains(lower, "корм") || strings.Contains(lower, "питани") {
		return "Питание — важнейший аспект здоровья вашего питомца! Основные правила: качественный корм по возрасту и виду, режим кормления, чистая вода.", nil
	}
	if strings.Contains(lower, "прививк") || strings.Contains(lower, "вакцин") {
		return "Схема вакцинации: собаки и кошки — первая прививка в 8–9 нед, ревакцинация в 12 нед, далее ежегодно. Обработка от глистов за 10–14 дней до прививки.", nil
	}
	if strings.Contains(lower, "лоток") || strings.Contains(lower, "туалет") {
		return "Приучение к лотку: лоток в тихое место, после еды и сна — в лоток, хвалите за успех, держите лоток чистым.", nil
	}
	if s.kserve != nil {
		inp := make([]float32, 0, len(text))
		for _, r := range text {
			inp = append(inp, float32(r))
		}
		if len(inp) > 0 {
			out, err := s.kserve.Predict(ctx, "chat", inp)
			if err == nil && len(out) > 0 {
				runes := make([]rune, len(out))
				for i, v := range out {
					runes[i] = rune(v)
				}
				return string(runes), nil
			}
		}
	}
	return "Могу посоветовать по кормлению, вакцинации, грумингу и поведению. Задайте конкретный вопрос.", nil
}
