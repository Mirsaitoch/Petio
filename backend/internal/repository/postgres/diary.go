package postgres

import (
	"context"
	"database/sql"

	"github.com/google/uuid"

	"petio/backend/internal/domain"
)

type DiaryRepository struct {
	db *sql.DB
}

func NewDiaryRepository(db *sql.DB) *DiaryRepository {
	return &DiaryRepository{db: db}
}

func (r *DiaryRepository) GetByPetID(ctx context.Context, petID, userID string) ([]domain.HealthDiaryEntry, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT id, pet_id, date, note FROM health_diary WHERE pet_id = $1 AND user_id = $2 ORDER BY date DESC`,
		petID, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	list := make([]domain.HealthDiaryEntry, 0)
	for rows.Next() {
		var e domain.HealthDiaryEntry
		if err := rows.Scan(&e.ID, &e.PetID, &e.Date, &e.Note); err != nil {
			return nil, err
		}
		e.UserID = userID
		list = append(list, e)
	}
	return list, rows.Err()
}

func (r *DiaryRepository) GetByID(ctx context.Context, id, userID string) (*domain.HealthDiaryEntry, error) {
	var e domain.HealthDiaryEntry
	err := r.db.QueryRowContext(ctx,
		`SELECT id, pet_id, date, note FROM health_diary WHERE id = $1 AND user_id = $2`,
		id, userID,
	).Scan(&e.ID, &e.PetID, &e.Date, &e.Note)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	e.UserID = userID
	return &e, nil
}

func (r *DiaryRepository) Create(ctx context.Context, e *domain.HealthDiaryEntry) error {
	if e.ID == "" {
		e.ID = uuid.New().String()
	}
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO health_diary (id, user_id, pet_id, date, note) VALUES ($1, $2, $3, $4, $5)`,
		e.ID, e.UserID, e.PetID, e.Date, e.Note,
	)
	return err
}

func (r *DiaryRepository) Update(ctx context.Context, e *domain.HealthDiaryEntry) error {
	res, err := r.db.ExecContext(ctx,
		`UPDATE health_diary SET date=$2, note=$3 WHERE id=$1 AND user_id=$4`,
		e.ID, e.Date, e.Note, e.UserID,
	)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *DiaryRepository) Delete(ctx context.Context, id, userID string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM health_diary WHERE id = $1 AND user_id = $2`, id, userID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return sql.ErrNoRows
	}
	return nil
}
