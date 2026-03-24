package moderation

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestCheckText_Success(t *testing.T) {
	reason := "toxicity"
	resp := TextResponse{
		Action:      "block",
		Blocked:     true,
		NeedsReview: false,
		Reason:      &reason,
		Confidence:  0.95,
		Scores: TextScores{
			Toxicity:       0.9,
			SevereToxicity: 0.1,
			Obscene:        0.8,
			Threat:         0.05,
			Insult:         0.7,
			IdentityAttack: 0.02,
			SexualExplicit: 0.01,
		},
	}

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, "/texts_scores", r.URL.Path)
		assert.Equal(t, "application/json", r.Header.Get("Content-Type"))
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
	defer srv.Close()

	client := New(srv.URL)
	result, err := client.CheckText(context.Background(), "bad text")
	require.NoError(t, err)
	require.NotNil(t, result)

	assert.True(t, result.Blocked)
	assert.Equal(t, "block", result.Action)
	require.NotNil(t, result.Reason)
	assert.Equal(t, "toxicity", *result.Reason)
	assert.InDelta(t, 0.95, result.Confidence, 0.001)
	assert.InDelta(t, 0.9, result.Scores.Toxicity, 0.001)
	assert.InDelta(t, 0.8, result.Scores.Obscene, 0.001)
	assert.InDelta(t, 0.7, result.Scores.Insult, 0.001)
}

func TestCheckImage_Success(t *testing.T) {
	reason := "nsfw_content"
	resp := ImageResponse{
		Action:      "block",
		Blocked:     true,
		NeedsReview: true,
		Reason:      &reason,
		Confidence:  0.88,
		Scores: ImageScores{
			NSFW:     0.85,
			Safe:     0.15,
			Medical:  0.01,
			Porn:     0.80,
			Violence: 0.02,
			Abuse:    0.03,
		},
	}

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, "/images_scores", r.URL.Path)
		assert.Contains(t, r.Header.Get("Content-Type"), "multipart/form-data")
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
	defer srv.Close()

	client := New(srv.URL)
	result, err := client.CheckImage(context.Background(), []byte{0xFF, 0xD8, 0xFF}, "test.jpg")
	require.NoError(t, err)
	require.NotNil(t, result)

	assert.True(t, result.Blocked)
	assert.InDelta(t, 0.85, result.Scores.NSFW, 0.001)
	assert.InDelta(t, 0.15, result.Scores.Safe, 0.001)
	assert.InDelta(t, 0.80, result.Scores.Porn, 0.001)
}

func TestCheckText_ErrorStatus(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte("internal error"))
	}))
	defer srv.Close()

	client := New(srv.URL)
	result, err := client.CheckText(context.Background(), "some text")
	assert.Error(t, err)
	assert.Nil(t, result)
	assert.Contains(t, err.Error(), "500")
}

func TestCheckText_NilClient(t *testing.T) {
	var client *Client
	result, err := client.CheckText(context.Background(), "text")
	assert.NoError(t, err)
	assert.Nil(t, result)
}

func TestCheckImage_NilClient(t *testing.T) {
	var client *Client
	result, err := client.CheckImage(context.Background(), []byte{0x01}, "img.png")
	assert.NoError(t, err)
	assert.Nil(t, result)
}

func TestNew_EmptyURL(t *testing.T) {
	client := New("")
	assert.Nil(t, client)
}
