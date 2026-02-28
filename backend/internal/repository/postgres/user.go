package postgres

import (
	"context"
	"database/sql"

	"github.com/google/uuid"

	"petio/backend/internal/domain"
)

type UserRepository struct {
	db *sql.DB
}

func NewUserRepository(db *sql.DB) *UserRepository {
	return &UserRepository{db: db}
}

func (r *UserRepository) GetByID(ctx context.Context, id string) (*domain.User, error) {
	var u domain.User
	err := r.db.QueryRowContext(ctx,
		`SELECT id, email, password FROM users WHERE id = $1`, id,
	).Scan(&u.ID, &u.Email, &u.Password)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	var u domain.User
	err := r.db.QueryRowContext(ctx,
		`SELECT id, email, password FROM users WHERE email = $1`, email,
	).Scan(&u.ID, &u.Email, &u.Password)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *UserRepository) Create(ctx context.Context, u *domain.User) error {
	if u.ID == "" {
		u.ID = uuid.New().String()
	}
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO users (id, email, password, name, username) VALUES ($1, $2, $3, '', '')`,
		u.ID, u.Email, u.Password,
	)
	return err
}

func (r *UserRepository) GetProfile(ctx context.Context, userID string) (*domain.UserProfile, error) {
	var p domain.UserProfile
	var avatar sql.NullString
	err := r.db.QueryRowContext(ctx,
		`SELECT name, username, avatar, bio, join_date FROM users WHERE id = $1`, userID,
	).Scan(&p.Name, &p.Username, &avatar, &p.Bio, &p.JoinDate)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if avatar.Valid {
		p.Avatar = &avatar.String
	}
	p.UserID = userID
	var petsCount, postsCount int
	_ = r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM pets WHERE user_id = $1`, userID).Scan(&petsCount)
	_ = r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM posts WHERE user_id = $1`, userID).Scan(&postsCount)
	p.PetsCount = petsCount
	p.PostsCount = postsCount
	return &p, nil
}

func (r *UserRepository) UpdateProfile(ctx context.Context, p *domain.UserProfile) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE users SET name=$2, username=$3, avatar=$4, bio=$5 WHERE id=$1`,
		p.UserID, p.Name, p.Username, p.Avatar, p.Bio,
	)
	return err
}
