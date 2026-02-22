package postgres

import (
	"context"
	"database/sql"

	"github.com/google/uuid"
	"github.com/lib/pq"

	"petio/backend/internal/domain"
)

type PetRepository struct {
	db *sql.DB
}

func NewPetRepository(db *sql.DB) *PetRepository {
	return &PetRepository{db: db}
}

func (r *PetRepository) GetByID(ctx context.Context, id, userID string) (*domain.Pet, error) {
	var p domain.Pet
	var photo sql.NullString
	var features pq.StringArray
	err := r.db.QueryRowContext(ctx,
		`SELECT id, user_id, name, species, breed, age, weight, photo, birth_date, COALESCE(features, '{}')
		 FROM pets WHERE id = $1 AND user_id = $2`,
		id, userID,
	).Scan(&p.ID, &p.UserID, &p.Name, &p.Species, &p.Breed, &p.Age, &p.Weight, &photo, &p.BirthDate, &features)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if photo.Valid {
		p.Photo = &photo.String
	}
	p.Features = features
	p.Vaccinations, _ = r.vaccinationsByPetID(ctx, id)
	return &p, nil
}

func (r *PetRepository) List(ctx context.Context, userID string) ([]domain.Pet, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT id, user_id, name, species, breed, age, weight, photo, birth_date, COALESCE(features, '{}')
		 FROM pets WHERE user_id = $1 ORDER BY name`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []domain.Pet
	for rows.Next() {
		var p domain.Pet
		var photo sql.NullString
		var features pq.StringArray
		if err := rows.Scan(&p.ID, &p.UserID, &p.Name, &p.Species, &p.Breed, &p.Age, &p.Weight, &photo, &p.BirthDate, &features); err != nil {
			return nil, err
		}
		if photo.Valid {
			p.Photo = &photo.String
		}
		p.Features = features
		p.Vaccinations, _ = r.vaccinationsByPetID(ctx, p.ID)
		list = append(list, p)
	}
	return list, rows.Err()
}

func (r *PetRepository) Create(ctx context.Context, pet *domain.Pet) error {
	if pet.ID == "" {
		pet.ID = uuid.New().String()
	}
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO pets (id, user_id, name, species, breed, age, weight, photo, birth_date, features)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		pet.ID, pet.UserID, pet.Name, pet.Species, pet.Breed, pet.Age, pet.Weight, pet.Photo, pet.BirthDate, pq.Array(pet.Features),
	)
	if err != nil {
		return err
	}
	for i := range pet.Vaccinations {
		v := &pet.Vaccinations[i]
		if v.ID == "" {
			v.ID = uuid.New().String()
		}
		_, err = r.db.ExecContext(ctx,
			`INSERT INTO vaccinations (id, pet_id, name, date, next_date) VALUES ($1, $2, $3, $4, $5)`,
			v.ID, pet.ID, v.Name, v.Date, v.NextDate,
		)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *PetRepository) Update(ctx context.Context, pet *domain.Pet) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE pets SET name=$2, species=$3, breed=$4, age=$5, weight=$6, photo=$7, birth_date=$8, features=$9
		 WHERE id=$1 AND user_id=$10`,
		pet.ID, pet.Name, pet.Species, pet.Breed, pet.Age, pet.Weight, pet.Photo, pet.BirthDate, pq.Array(pet.Features), pet.UserID,
	)
	if err != nil {
		return err
	}
	_, _ = r.db.ExecContext(ctx, `DELETE FROM vaccinations WHERE pet_id = $1`, pet.ID)
	for i := range pet.Vaccinations {
		v := &pet.Vaccinations[i]
		if v.ID == "" {
			v.ID = uuid.New().String()
		}
		_, err = r.db.ExecContext(ctx,
			`INSERT INTO vaccinations (id, pet_id, name, date, next_date) VALUES ($1, $2, $3, $4, $5)`,
			v.ID, pet.ID, v.Name, v.Date, v.NextDate,
		)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *PetRepository) Delete(ctx context.Context, id, userID string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM pets WHERE id = $1 AND user_id = $2`, id, userID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *PetRepository) vaccinationsByPetID(ctx context.Context, petID string) ([]domain.Vaccination, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT id, name, date, next_date FROM vaccinations WHERE pet_id = $1`, petID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []domain.Vaccination
	for rows.Next() {
		var v domain.Vaccination
		if err := rows.Scan(&v.ID, &v.Name, &v.Date, &v.NextDate); err != nil {
			return nil, err
		}
		list = append(list, v)
	}
	return list, rows.Err()
}
