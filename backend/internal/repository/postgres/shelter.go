package postgres

import (
	"context"
	"database/sql"

	"github.com/google/uuid"

	"petio/backend/internal/domain"
)

type ShelterRepository struct {
	db *sql.DB
}

func NewShelterRepository(db *sql.DB) *ShelterRepository {
	return &ShelterRepository{db: db}
}

func (r *ShelterRepository) List(ctx context.Context) ([]domain.Shelter, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT id, image, type, name, description, website_url FROM shelters ORDER BY name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	list := make([]domain.Shelter, 0)
	for rows.Next() {
		var s domain.Shelter
		var img sql.NullString
		if err := rows.Scan(&s.ID, &img, &s.Type, &s.Name, &s.Description, &s.WebsiteURL); err != nil {
			return nil, err
		}
		if img.Valid {
			s.Image = &img.String
		}
		list = append(list, s)
	}
	return list, rows.Err()
}

func (r *ShelterRepository) GetByID(ctx context.Context, id string) (*domain.Shelter, error) {
	var s domain.Shelter
	var img sql.NullString
	err := r.db.QueryRowContext(ctx,
		`SELECT id, image, type, name, description, website_url FROM shelters WHERE id = $1`, id,
	).Scan(&s.ID, &img, &s.Type, &s.Name, &s.Description, &s.WebsiteURL)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if img.Valid {
		s.Image = &img.String
	}
	return &s, nil
}

func (r *ShelterRepository) Create(ctx context.Context, s *domain.Shelter) error {
	if s.ID == "" {
		s.ID = uuid.New().String()
	}
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO shelters (id, image, type, name, description, website_url) VALUES ($1, $2, $3, $4, $5, $6)`,
		s.ID, s.Image, s.Type, s.Name, s.Description, s.WebsiteURL,
	)
	return err
}

func (r *ShelterRepository) Update(ctx context.Context, s *domain.Shelter) error {
	res, err := r.db.ExecContext(ctx,
		`UPDATE shelters SET image=$2, type=$3, name=$4, description=$5, website_url=$6 WHERE id=$1`,
		s.ID, s.Image, s.Type, s.Name, s.Description, s.WebsiteURL,
	)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *ShelterRepository) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM shelters WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return sql.ErrNoRows
	}
	return nil
}
