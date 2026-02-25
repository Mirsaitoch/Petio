package postgres

import (
	"context"
	"database/sql"

	"github.com/google/uuid"

	"petio/backend/internal/domain"
)

type ReminderRepository struct {
	db *sql.DB
}

func NewReminderRepository(db *sql.DB) *ReminderRepository {
	return &ReminderRepository{db: db}
}

func (r *ReminderRepository) List(ctx context.Context, userID string, petID *string) ([]domain.Reminder, error) {
	var rows *sql.Rows
	var err error
	if petID != nil && *petID != "" {
		rows, err = r.db.QueryContext(ctx,
			`SELECT id, pet_id, pet_name, type, title, date, time, completed FROM reminders WHERE user_id = $1 AND pet_id = $2 ORDER BY date, time`,
			userID, *petID,
		)
	} else {
		rows, err = r.db.QueryContext(ctx,
			`SELECT id, pet_id, pet_name, type, title, date, time, completed FROM reminders WHERE user_id = $1 ORDER BY date, time`,
			userID,
		)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	list := make([]domain.Reminder, 0)
	for rows.Next() {
		var rem domain.Reminder
		if err := rows.Scan(&rem.ID, &rem.PetID, &rem.PetName, &rem.Type, &rem.Title, &rem.Date, &rem.Time, &rem.Completed); err != nil {
			return nil, err
		}
		rem.UserID = userID
		list = append(list, rem)
	}
	return list, rows.Err()
}

func (r *ReminderRepository) GetByID(ctx context.Context, id, userID string) (*domain.Reminder, error) {
	var rem domain.Reminder
	err := r.db.QueryRowContext(ctx,
		`SELECT id, pet_id, pet_name, type, title, date, time, completed FROM reminders WHERE id = $1 AND user_id = $2`,
		id, userID,
	).Scan(&rem.ID, &rem.PetID, &rem.PetName, &rem.Type, &rem.Title, &rem.Date, &rem.Time, &rem.Completed)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	rem.UserID = userID
	return &rem, nil
}

func (r *ReminderRepository) Create(ctx context.Context, rem *domain.Reminder) error {
	if rem.ID == "" {
		rem.ID = uuid.New().String()
	}
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO reminders (id, user_id, pet_id, pet_name, type, title, date, time, completed)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
		rem.ID, rem.UserID, rem.PetID, rem.PetName, rem.Type, rem.Title, rem.Date, rem.Time, rem.Completed,
	)
	return err
}

func (r *ReminderRepository) Update(ctx context.Context, rem *domain.Reminder) error {
	res, err := r.db.ExecContext(ctx,
		`UPDATE reminders SET pet_name=$2, type=$3, title=$4, date=$5, time=$6, completed=$7 WHERE id=$1 AND user_id=$8`,
		rem.ID, rem.PetName, rem.Type, rem.Title, rem.Date, rem.Time, rem.Completed, rem.UserID,
	)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *ReminderRepository) Delete(ctx context.Context, id, userID string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM reminders WHERE id = $1 AND user_id = $2`, id, userID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return sql.ErrNoRows
	}
	return nil
}
