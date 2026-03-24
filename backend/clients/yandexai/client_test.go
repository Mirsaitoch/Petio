package yandexai

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestExtractText_Normal(t *testing.T) {
	resp := ResponseData{
		Output: []OutputItem{
			{
				Role:   "assistant",
				Status: "completed",
				Content: []ContentBlock{
					{Text: "Hello world", Type: "text"},
				},
			},
		},
	}
	assert.Equal(t, "Hello world", resp.ExtractText())
}

func TestExtractText_EmptyOutput(t *testing.T) {
	resp := ResponseData{
		Output: []OutputItem{},
	}
	assert.Equal(t, "", resp.ExtractText())
}

func TestExtractText_NilOutput(t *testing.T) {
	resp := ResponseData{}
	assert.Equal(t, "", resp.ExtractText())
}

func TestExtractText_MultipleContentBlocks(t *testing.T) {
	// ExtractText returns the first non-empty text block
	resp := ResponseData{
		Output: []OutputItem{
			{
				Role:   "assistant",
				Status: "completed",
				Content: []ContentBlock{
					{Text: "", Type: "text"},
					{Text: "second block", Type: "text"},
					{Text: "third block", Type: "text"},
				},
			},
		},
	}
	assert.Equal(t, "second block", resp.ExtractText())
}

func TestExtractText_AllEmptyContent(t *testing.T) {
	resp := ResponseData{
		Output: []OutputItem{
			{
				Content: []ContentBlock{
					{Text: "", Type: "text"},
					{Text: "", Type: "text"},
				},
			},
		},
	}
	assert.Equal(t, "", resp.ExtractText())
}

func TestExtractText_EmptyContentSlice(t *testing.T) {
	resp := ResponseData{
		Output: []OutputItem{
			{
				Content: []ContentBlock{},
			},
		},
	}
	assert.Equal(t, "", resp.ExtractText())
}
