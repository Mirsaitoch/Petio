// @title       Petio API
// @version     1.0
// @description API приложения для ухода за домашними животными
// @Host       localhost:8080
// @BasePath   /
// @securityDefinitions.apikey BearerAuth
// @in         header
// @name       Authorization
package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "petio/backend/docs"

	"petio/backend/internal/app"
	"petio/backend/internal/config"
)

func main() {
	cfg := config.Load()
	application, err := app.New(cfg)
	if err != nil {
		log.Fatal(err)
	}
	go func() {
		if err := application.Run(); err != nil && err != context.Canceled {
			log.Println("server:", err)
		}
	}()
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := application.Shutdown(ctx); err != nil {
		log.Println("shutdown:", err)
	}
}
