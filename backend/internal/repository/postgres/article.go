package postgres

import (
	"context"
	"database/sql"

	"github.com/google/uuid"

	"petio/backend/internal/domain"
)

type ArticleRepository struct {
	db *sql.DB
}

func NewArticleRepository(db *sql.DB) *ArticleRepository {
	return &ArticleRepository{db: db}
}

func (r *ArticleRepository) List(ctx context.Context) ([]domain.Article, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT id, title, description, category, image, pet_type, care_type, read_time FROM articles ORDER BY title`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	list := make([]domain.Article, 0)
	for rows.Next() {
		var a domain.Article
		var img sql.NullString
		if err := rows.Scan(&a.ID, &a.Title, &a.Description, &a.Category, &img, &a.PetType, &a.CareType, &a.ReadTime); err != nil {
			return nil, err
		}
		if img.Valid {
			a.Image = &img.String
		}
		list = append(list, a)
	}
	return list, rows.Err()
}

func (r *ArticleRepository) GetByID(ctx context.Context, id string) (*domain.Article, error) {
	var a domain.Article
	var img sql.NullString
	err := r.db.QueryRowContext(ctx,
		`SELECT id, title, description, category, image, pet_type, care_type, read_time FROM articles WHERE id = $1`,
		id,
	).Scan(&a.ID, &a.Title, &a.Description, &a.Category, &img, &a.PetType, &a.CareType, &a.ReadTime)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if img.Valid {
		a.Image = &img.String
	}
	return &a, nil
}

func (r *ArticleRepository) Create(ctx context.Context, a *domain.Article) error {
	if a.ID == "" {
		a.ID = uuid.New().String()
	}
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO articles (id, title, description, category, image, pet_type, care_type, read_time)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		a.ID, a.Title, a.Description, a.Category, a.Image, a.PetType, a.CareType, a.ReadTime,
	)
	return err
}

func (r *ArticleRepository) Update(ctx context.Context, a *domain.Article) error {
	res, err := r.db.ExecContext(ctx,
		`UPDATE articles SET title=$2, description=$3, category=$4, image=$5, pet_type=$6, care_type=$7, read_time=$8 WHERE id=$1`,
		a.ID, a.Title, a.Description, a.Category, a.Image, a.PetType, a.CareType, a.ReadTime,
	)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *ArticleRepository) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM articles WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return sql.ErrNoRows
	}
	return nil
}
