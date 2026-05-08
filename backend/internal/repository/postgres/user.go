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
	var email, password sql.NullString
	err := r.db.QueryRowContext(ctx,
		`SELECT id, email, password FROM users WHERE id = $1`, id,
	).Scan(&u.ID, &email, &password)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	u.Email = email.String
	u.Password = password.String
	return &u, nil
}

func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	var u domain.User
	var emailVal, password sql.NullString
	err := r.db.QueryRowContext(ctx,
		`SELECT id, email, password FROM users WHERE email = $1`, email,
	).Scan(&u.ID, &emailVal, &password)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	u.Email = emailVal.String
	u.Password = password.String
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
	var avatar, email sql.NullString
	err := r.db.QueryRowContext(ctx,
		`SELECT name, username, avatar, bio, join_date, email FROM users WHERE id = $1`, userID,
	).Scan(&p.Name, &p.Username, &avatar, &p.Bio, &p.JoinDate, &email)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if avatar.Valid {
		p.Avatar = &avatar.String
	}
	if email.Valid {
		p.Email = &email.String
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

// CreateAnonymous creates a user with no email/password (device-only account).
func (r *UserRepository) CreateAnonymous(ctx context.Context) (*domain.User, error) {
	u := &domain.User{ID: uuid.New().String()}
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO users (id, name, username) VALUES ($1, '', '')`,
		u.ID,
	)
	if err != nil {
		return nil, err
	}
	return u, nil
}

// LinkDevice associates a device_id with a user account.
func (r *UserRepository) LinkDevice(ctx context.Context, userID, deviceID string) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO device_accounts (device_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
		deviceID, userID,
	)
	return err
}

// GetByDeviceID returns all users linked to a device.
func (r *UserRepository) GetByDeviceID(ctx context.Context, deviceID string) ([]domain.User, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT u.id, u.email, u.password
		 FROM users u
		 JOIN device_accounts da ON da.user_id = u.id
		 WHERE da.device_id = $1
		 ORDER BY da.created_at`,
		deviceID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []domain.User
	for rows.Next() {
		var u domain.User
		var email, password sql.NullString
		if err := rows.Scan(&u.ID, &email, &password); err != nil {
			return nil, err
		}
		u.Email = email.String
		u.Password = password.String
		users = append(users, u)
	}
	return users, rows.Err()
}

// DeviceHasUser checks whether a device is linked to a specific user.
func (r *UserRepository) DeviceHasUser(ctx context.Context, deviceID, userID string) (bool, error) {
	var exists bool
	err := r.db.QueryRowContext(ctx,
		`SELECT EXISTS(SELECT 1 FROM device_accounts WHERE device_id=$1 AND user_id=$2)`,
		deviceID, userID,
	).Scan(&exists)
	return exists, err
}

// UpdatePassword changes the password for an existing user.
func (r *UserRepository) UpdatePassword(ctx context.Context, userID, passwordHash string) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE users SET password=$2 WHERE id=$1`,
		userID, passwordHash,
	)
	return err
}

// LinkEmail attaches an email + password to an existing anonymous account.
func (r *UserRepository) LinkEmail(ctx context.Context, userID, email, passwordHash string) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE users SET email=$2, password=$3 WHERE id=$1`,
		userID, email, passwordHash,
	)
	return err
}
