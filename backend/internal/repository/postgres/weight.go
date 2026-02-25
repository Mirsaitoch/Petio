package postgres

import (
	"context"
	"database/sql"

	"petio/backend/internal/domain"
)

type WeightRepository struct {
	db *sql.DB
}

func NewWeightRepository(db *sql.DB) *WeightRepository {
	return &WeightRepository{db: db}
}

func (r *WeightRepository) GetByPetID(ctx context.Context, petID, userID string) ([]domain.WeightRecord, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT date, weight FROM weight_records wr
		 JOIN pets p ON p.id = wr.pet_id AND p.user_id = $2
		 WHERE wr.pet_id = $1 ORDER BY date`,
		petID, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	list := make([]domain.WeightRecord, 0)
	for rows.Next() {
		var w domain.WeightRecord
		if err := rows.Scan(&w.Date, &w.Weight); err != nil {
			return nil, err
		}
		list = append(list, w)
	}
	return list, rows.Err()
}

func (r *WeightRepository) GetByPetIDAndDate(ctx context.Context, petID, date, userID string) (*domain.WeightRecord, error) {
	var w domain.WeightRecord
	err := r.db.QueryRowContext(ctx,
		`SELECT wr.date, wr.weight FROM weight_records wr
		 JOIN pets p ON p.id = wr.pet_id AND p.user_id = $3
		 WHERE wr.pet_id = $1 AND wr.date = $2`,
		petID, date, userID,
	).Scan(&w.Date, &w.Weight)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &w, nil
}

func (r *WeightRepository) Add(ctx context.Context, petID, userID string, rec domain.WeightRecord) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO weight_records (pet_id, date, weight)
		 SELECT $1, $2, $3 WHERE EXISTS (SELECT 1 FROM pets WHERE id = $1 AND user_id = $4)
		 ON CONFLICT (pet_id, date) DO UPDATE SET weight = $3`,
		petID, rec.Date, rec.Weight, userID,
	)
	return err
}

func (r *WeightRepository) Update(ctx context.Context, petID, userID string, rec domain.WeightRecord) error {
	res, err := r.db.ExecContext(ctx,
		`UPDATE weight_records SET weight = $3
		 WHERE pet_id = $1 AND date = $2 AND EXISTS (SELECT 1 FROM pets WHERE id = $1 AND user_id = $4)`,
		petID, rec.Date, rec.Weight, userID,
	)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *WeightRepository) Delete(ctx context.Context, petID, date, userID string) error {
	res, err := r.db.ExecContext(ctx,
		`DELETE FROM weight_records WHERE pet_id = $1 AND date = $2
		 AND EXISTS (SELECT 1 FROM pets WHERE id = $1 AND user_id = $3)`,
		petID, date, userID,
	)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return sql.ErrNoRows
	}
	return nil
}
