package app

import (
	"context"
	"database/sql"
	"fmt"
	"net/http"
	"time"

	"petio/backend/clients/kserve"
	"petio/backend/clients/s3"
	"petio/backend/internal/config"
	"petio/backend/internal/migrations"
	"petio/backend/internal/repository/postgres"
	"petio/backend/internal/service"
	"petio/backend/internal/transport/http/handlers"
	httptransport "petio/backend/internal/transport/http"
)

type App struct {
	cfg    *config.Config
	db     *sql.DB
	kserve *kserve.Client
	server *http.Server
}

func New(cfg *config.Config) (*App, error) {
	db, err := postgres.New(cfg.DB.DSN)
	if err != nil {
		return nil, fmt.Errorf("db: %w", err)
	}
	if err := migrations.Run(db); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("migrate: %w", err)
	}
	kc := kserve.New(cfg.KServe.BaseURL)
	if !cfg.S3.S3Configured() {
		msg := "S3 required at startup. Check .env (see config log for loaded path). Missing:"
		if cfg.S3.Bucket == "" {
			msg += " S3_BUCKET"
		}
		if cfg.S3.AccessKeyID == "" {
			msg += " AWS_ACCESS_KEY_ID"
		}
		if cfg.S3.SecretAccessKey == "" {
			msg += " AWS_SECRET_ACCESS_KEY"
		}
		return nil, fmt.Errorf("%s", msg)
	}
	s3Client := s3.New(s3.Config{
		Bucket:          cfg.S3.Bucket,
		Region:          cfg.S3.Region,
		Endpoint:        cfg.S3.Endpoint,
		BaseURL:         cfg.S3.BaseURL,
		AccessKeyID:     cfg.S3.AccessKeyID,
		SecretAccessKey: cfg.S3.SecretAccessKey,
	})
	petRepo := postgres.NewPetRepository(db)
	reminderRepo := postgres.NewReminderRepository(db)
	weightRepo := postgres.NewWeightRepository(db)
	diaryRepo := postgres.NewDiaryRepository(db)
	articleRepo := postgres.NewArticleRepository(db)
	postRepo := postgres.NewPostRepository(db)
	userRepo := postgres.NewUserRepository(db)

	authHandler := handlers.NewAuthHandler(userRepo, cfg.JWT.Secret, cfg.JWT.Expiration)
	petHandler := handlers.NewPetHandler(petRepo)
	reminderHandler := handlers.NewReminderHandler(reminderRepo)
	weightHandler := handlers.NewWeightHandler(weightRepo)
	diaryHandler := handlers.NewDiaryHandler(diaryRepo)
	articleHandler := handlers.NewArticleHandler(articleRepo)
	postHandler := handlers.NewPostHandler(postRepo)
	chatService := service.NewChatService(kc)
	chatHandler := handlers.NewChatHandler(chatService)
	profileHandler := handlers.NewProfileHandler(userRepo)
	uploadHandler := handlers.NewUploadHandler(s3Client)

	router := httptransport.NewRouter(
		authHandler, petHandler, reminderHandler, weightHandler,
		diaryHandler, articleHandler, postHandler, chatHandler, profileHandler, uploadHandler,
		cfg.JWT.Secret,
	)

	return &App{
		cfg:    cfg,
		db:     db,
		kserve: kc,
		server: &http.Server{
			Addr:         cfg.HTTPAddr,
			Handler:      router,
			ReadTimeout:  15 * time.Second,
			WriteTimeout: 15 * time.Second,
		},
	}, nil
}

func (a *App) Run() error {
	return a.server.ListenAndServe()
}

func (a *App) Shutdown(ctx context.Context) error {
	if a.db != nil {
		_ = a.db.Close()
	}
	if a.server != nil {
		return a.server.Shutdown(ctx)
	}
	return nil
}
