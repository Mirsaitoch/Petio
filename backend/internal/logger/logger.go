package logger

import (
	"context"
	"os"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

type ctxKey struct{}

// New создаёт *zap.Logger. В dev-режиме — human-readable, в prod — JSON для ELK.
func New() *zap.Logger {
	env := os.Getenv("APP_ENV")

	var cfg zap.Config
	if env == "production" {
		cfg = zap.NewProductionConfig()
	} else {
		cfg = zap.NewDevelopmentConfig()
		cfg.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
	}

	cfg.EncoderConfig.TimeKey = "ts"
	cfg.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder

	l, _ := cfg.Build(zap.AddStacktrace(zapcore.ErrorLevel))
	return l
}

// ToCtx кладёт логгер в контекст.
func ToCtx(ctx context.Context, l *zap.Logger) context.Context {
	return context.WithValue(ctx, ctxKey{}, l)
}

// FromCtx достаёт логгер из контекста. Если нет — возвращает глобальный.
func FromCtx(ctx context.Context) *zap.Logger {
	if l, ok := ctx.Value(ctxKey{}).(*zap.Logger); ok {
		return l
	}
	return zap.L()
}
