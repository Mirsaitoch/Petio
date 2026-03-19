package postgres

import (
	"context"
	"database/sql"

	"github.com/google/uuid"
	"github.com/lib/pq"

	"petio/backend/internal/domain"
)

type ShelterRepository struct {
	db *sql.DB
}

func NewShelterRepository(db *sql.DB) *ShelterRepository {
	return &ShelterRepository{db: db}
}

const shelterColumns = `id, name, tagline, image_url, category, city, founded, phone, website, description, long_description, COALESCE(tags, '{}'), COALESCE(needs, '{}')`

func scanShelter(row interface{ Scan(...any) error }) (*domain.Shelter, error) {
	var s domain.Shelter
	var tags, needs pq.StringArray
	err := row.Scan(
		&s.ID, &s.Name, &s.Tagline, &s.ImageURL, &s.Category,
		&s.City, &s.Founded, &s.Phone, &s.Website,
		&s.Description, &s.LongDescription, &tags, &needs,
	)
	if err != nil {
		return nil, err
	}
	s.Tags = tags
	s.Needs = needs
	if s.Tags == nil {
		s.Tags = []string{}
	}
	if s.Needs == nil {
		s.Needs = []string{}
	}
	return &s, nil
}

func (r *ShelterRepository) List(ctx context.Context) ([]domain.Shelter, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT `+shelterColumns+` FROM shelters ORDER BY name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	list := make([]domain.Shelter, 0)
	for rows.Next() {
		s, err := scanShelter(rows)
		if err != nil {
			return nil, err
		}
		list = append(list, *s)
	}
	return list, rows.Err()
}

func (r *ShelterRepository) GetByID(ctx context.Context, id string) (*domain.Shelter, error) {
	row := r.db.QueryRowContext(ctx,
		`SELECT `+shelterColumns+` FROM shelters WHERE id = $1`, id)
	s, err := scanShelter(row)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return s, nil
}

func (r *ShelterRepository) Create(ctx context.Context, s *domain.Shelter) error {
	if s.ID == "" {
		s.ID = uuid.New().String()
	}
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO shelters (id, name, tagline, image_url, category, city, founded, phone, website, description, long_description, tags, needs)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
		s.ID, s.Name, s.Tagline, s.ImageURL, s.Category,
		s.City, s.Founded, s.Phone, s.Website,
		s.Description, s.LongDescription, pq.Array(s.Tags), pq.Array(s.Needs),
	)
	return err
}

func (r *ShelterRepository) Update(ctx context.Context, s *domain.Shelter) error {
	res, err := r.db.ExecContext(ctx,
		`UPDATE shelters SET name=$2, tagline=$3, image_url=$4, category=$5, city=$6, founded=$7, phone=$8, website=$9, description=$10, long_description=$11, tags=$12, needs=$13
		 WHERE id=$1`,
		s.ID, s.Name, s.Tagline, s.ImageURL, s.Category,
		s.City, s.Founded, s.Phone, s.Website,
		s.Description, s.LongDescription, pq.Array(s.Tags), pq.Array(s.Needs),
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
