package postgres

import (
	"context"
	"database/sql"
	"time"
)

type PasswordResetTokenRepository struct {
	db *sql.DB
}

func NewPasswordResetTokenRepository(db *sql.DB) *PasswordResetTokenRepository {
	return &PasswordResetTokenRepository{db: db}
}

func (r *PasswordResetTokenRepository) Save(ctx context.Context, userID, tokenHash string, expiresAt time.Time) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO password_reset_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
		userID, tokenHash, expiresAt,
	)
	return err
}

func (r *PasswordResetTokenRepository) GetUserIDByTokenHash(ctx context.Context, tokenHash string) (userID string, expiresAt time.Time, err error) {
	err = r.db.QueryRowContext(ctx,
		`SELECT user_id, expires_at FROM password_reset_tokens WHERE token_hash = $1`,
		tokenHash,
	).Scan(&userID, &expiresAt)
	if err == sql.ErrNoRows {
		return "", time.Time{}, nil
	}
	return userID, expiresAt, err
}

func (r *PasswordResetTokenRepository) DeleteByTokenHash(ctx context.Context, tokenHash string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM password_reset_tokens WHERE token_hash = $1`, tokenHash)
	return err
}
