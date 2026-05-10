// @title       Petio API
// @version     1.0
// @description API приложения для ухода за домашними животными
// @Host
// @BasePath   /
// @securityDefinitions.apikey BearerAuth
// @in         header
// @name       Authorization
package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "petio/backend/docs"

	"go.uber.org/zap"

	"petio/backend/internal/app"
	"petio/backend/internal/config"
	"petio/backend/internal/logger"
)

func main() {
	log := logger.New()
	defer func() { _ = log.Sync() }()
	zap.ReplaceGlobals(log)

	cfg := config.Load(log)
	application, err := app.New(cfg, log)
	if err != nil {
		log.Fatal("failed to create app", zap.Error(err))
	}

	go func() {
		if err := application.Run(); err != nil && err != context.Canceled {
			log.Error("server stopped", zap.Error(err))
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	sig := <-quit
	log.Info("shutting down", zap.String("signal", sig.String()))

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := application.Shutdown(ctx); err != nil {
		log.Error("shutdown error", zap.Error(err))
	}
	log.Info("server stopped")
}
