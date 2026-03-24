package postgres

import (
	"context"
	"database/sql"
	"time"
)

type EmailVerificationTokenRepository struct {
	db *sql.DB
}

func NewEmailVerificationTokenRepository(db *sql.DB) *EmailVerificationTokenRepository {
	return &EmailVerificationTokenRepository{db: db}
}

func (r *EmailVerificationTokenRepository) Save(ctx context.Context, userID, email, passwordHash, tokenHash string, expiresAt time.Time) error {
	// Delete any existing tokens for this user first
	_, _ = r.db.ExecContext(ctx, `DELETE FROM email_verification_tokens WHERE user_id = $1`, userID)
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO email_verification_tokens (user_id, email, password_hash, token_hash, expires_at) VALUES ($1, $2, $3, $4, $5)`,
		userID, email, passwordHash, tokenHash, expiresAt,
	)
	return err
}

func (r *EmailVerificationTokenRepository) GetByTokenHash(ctx context.Context, tokenHash string) (userID, email, passwordHash string, expiresAt time.Time, err error) {
	err = r.db.QueryRowContext(ctx,
		`SELECT user_id, email, password_hash, expires_at FROM email_verification_tokens WHERE token_hash = $1`,
		tokenHash,
	).Scan(&userID, &email, &passwordHash, &expiresAt)
	if err == sql.ErrNoRows {
		return "", "", "", time.Time{}, nil
	}
	return
}

func (r *EmailVerificationTokenRepository) DeleteByTokenHash(ctx context.Context, tokenHash string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM email_verification_tokens WHERE token_hash = $1`, tokenHash)
	return err
}

func (r *EmailVerificationTokenRepository) DeleteByUserID(ctx context.Context, userID string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM email_verification_tokens WHERE user_id = $1`, userID)
	return err
}
