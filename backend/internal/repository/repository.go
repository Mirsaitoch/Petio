package repository

import (
	"context"
	"time"

	"petio/backend/internal/domain"
)

type PetRepository interface {
	GetByID(ctx context.Context, id, userID string) (*domain.Pet, error)
	List(ctx context.Context, userID string) ([]domain.Pet, error)
	Create(ctx context.Context, pet *domain.Pet) error
	Update(ctx context.Context, pet *domain.Pet) error
	Delete(ctx context.Context, id, userID string) error
}

type ReminderRepository interface {
	List(ctx context.Context, userID string, petID *string) ([]domain.Reminder, error)
	GetByID(ctx context.Context, id, userID string) (*domain.Reminder, error)
	Create(ctx context.Context, r *domain.Reminder) error
	Update(ctx context.Context, r *domain.Reminder) error
	Delete(ctx context.Context, id, userID string) error
}

type WeightRepository interface {
	GetByPetID(ctx context.Context, petID, userID string) ([]domain.WeightRecord, error)
	GetByPetIDAndDate(ctx context.Context, petID, userID string, date time.Time) (*domain.WeightRecord, error)
	Add(ctx context.Context, petID, userID string, r domain.WeightRecord) error
	Update(ctx context.Context, petID, userID string, r domain.WeightRecord) error
	Delete(ctx context.Context, petID, userID string, date time.Time) error
}

type DiaryRepository interface {
	GetByPetID(ctx context.Context, petID, userID string) ([]domain.HealthDiaryEntry, error)
	GetByID(ctx context.Context, id, userID string) (*domain.HealthDiaryEntry, error)
	Create(ctx context.Context, e *domain.HealthDiaryEntry) error
	Update(ctx context.Context, e *domain.HealthDiaryEntry) error
	Delete(ctx context.Context, id, userID string) error
}

type ArticleRepository interface {
	List(ctx context.Context) ([]domain.Article, error)
	GetByID(ctx context.Context, id string) (*domain.Article, error)
	Create(ctx context.Context, a *domain.Article) error
	Update(ctx context.Context, a *domain.Article) error
	Delete(ctx context.Context, id string) error
}

type PostRepository interface {
	List(ctx context.Context, userID string, club *string) ([]domain.Post, error)
	ListPaginated(ctx context.Context, userID string, req domain.PostsRequest) (*domain.PostsResponse, error)
	GetByID(ctx context.Context, id, userID string) (*domain.Post, error)
	Create(ctx context.Context, p *domain.Post) error
	Update(ctx context.Context, p *domain.Post) error
	Delete(ctx context.Context, id, userID string) error
	SetLiked(ctx context.Context, postID, userID string, liked bool) error
	AddComment(ctx context.Context, postID string, c *domain.Comment) error
}

type UserRepository interface {
	GetByID(ctx context.Context, id string) (*domain.User, error)
	GetByEmail(ctx context.Context, email string) (*domain.User, error)
	Create(ctx context.Context, u *domain.User) error
	GetProfile(ctx context.Context, userID string) (*domain.UserProfile, error)
	UpdateProfile(ctx context.Context, p *domain.UserProfile) error
}
