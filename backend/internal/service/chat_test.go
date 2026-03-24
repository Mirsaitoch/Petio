package service

import (
	"petio/backend/internal/domain"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

// --- parseClassification ---

func TestParseClassification(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		wantCat     int
		wantContext bool
	}{
		{"simple no context", "10", 1, false},
		{"simple with context", "11", 1, true},
		{"category 3 no context", "30", 3, false},
		{"category 4 with context", "41", 4, true},
		{"category 0 no context", "00", 0, false},
		{"category 0 with context", "01", 0, true},
		{"empty string defaults", "", 1, true},
		{"single char defaults", "3", 1, true},
		{"garbage defaults", "x", 1, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := parseClassification(tt.input)
			assert.Equal(t, tt.wantCat, result.Category, "Category")
			assert.Equal(t, tt.wantContext, result.NeedContext, "NeedContext")
		})
	}
}

func TestParseClassification_OutOfRangeCategory(t *testing.T) {
	// '9' - '0' = 9 which is > 4, so category should be reset to 1
	result := parseClassification("90")
	assert.Equal(t, 1, result.Category)
	assert.False(t, result.NeedContext)
}

// --- categoryLabel ---

func TestCategoryLabel(t *testing.T) {
	tests := []struct {
		cat  int
		want string
	}{
		{0, "simple"},
		{1, "complex"},
		{2, "clarification"},
		{3, "off_topic"},
		{4, "gratitude"},
		{99, "unknown"},
		{-1, "unknown"},
	}

	for _, tt := range tests {
		t.Run(tt.want, func(t *testing.T) {
			assert.Equal(t, tt.want, categoryLabel(tt.cat))
		})
	}
}

// --- buildChatHistory ---

func TestBuildChatHistory_Empty(t *testing.T) {
	result := buildChatHistory([]domain.ChatMessage{})
	assert.Equal(t, "", result)
}

func TestBuildChatHistory_SingleMessage(t *testing.T) {
	msgs := []domain.ChatMessage{
		{Role: "user", Content: "hello"},
	}
	result := buildChatHistory(msgs)
	assert.Equal(t, "", result)
}

func TestBuildChatHistory_MultipleMessages(t *testing.T) {
	msgs := []domain.ChatMessage{
		{Role: "user", Content: "first question", CreatedAt: time.Now()},
		{Role: "assistant", Content: "first answer", CreatedAt: time.Now()},
		{Role: "user", Content: "current question", CreatedAt: time.Now()},
	}
	result := buildChatHistory(msgs)

	// Should include first two messages but NOT the last one
	assert.Contains(t, result, "user: first question")
	assert.Contains(t, result, "assistant: first answer")
	assert.NotContains(t, result, "current question")

	// Verify format: each line is "role: content\n"
	lines := strings.Split(strings.TrimRight(result, "\n"), "\n")
	assert.Len(t, lines, 2)
	assert.Equal(t, "user: first question", lines[0])
	assert.Equal(t, "assistant: first answer", lines[1])
}

// --- generateTitle ---

func TestGenerateTitle_Normal(t *testing.T) {
	svc := &ChatService{}
	title := svc.generateTitle("How to feed a cat")
	assert.Equal(t, "How to feed a cat", title)
}

func TestGenerateTitle_Empty(t *testing.T) {
	svc := &ChatService{}
	title := svc.generateTitle("")
	assert.Equal(t, "Новый чат", title)
}

func TestGenerateTitle_LongText(t *testing.T) {
	svc := &ChatService{}
	longText := strings.Repeat("word ", 20) // 100 chars
	title := svc.generateTitle(longText)

	assert.LessOrEqual(t, len(title), 50)
	assert.True(t, strings.HasSuffix(title, "..."))
}

func TestGenerateTitle_ExactlyFiftyChars(t *testing.T) {
	svc := &ChatService{}
	// Build text that after Join is exactly 50 chars - no truncation needed
	text := strings.Repeat("a", 50)
	title := svc.generateTitle(text)
	assert.Equal(t, text, title)
}
