package postgres

import (
	"context"
	"database/sql"

	"github.com/google/uuid"

	"petio/backend/internal/domain"
)

type PostRepository struct {
	db *sql.DB
}

func NewPostRepository(db *sql.DB) *PostRepository {
	return &PostRepository{db: db}
}

func (r *PostRepository) List(ctx context.Context, userID string, club *string) ([]domain.Post, error) {
	var rows *sql.Rows
	var err error
	if club != nil && *club != "" && *club != "Все" {
		rows, err = r.db.QueryContext(ctx,
			`SELECT id, user_id, author, avatar, content, image, likes, club, timestamp FROM posts WHERE club = $1 ORDER BY timestamp DESC`,
			*club,
		)
	} else {
		rows, err = r.db.QueryContext(ctx,
			`SELECT id, user_id, author, avatar, content, image, likes, club, timestamp FROM posts ORDER BY timestamp DESC`,
		)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	list := make([]domain.Post, 0)
	for rows.Next() {
		var p domain.Post
		var avatar, img sql.NullString
		if err := rows.Scan(&p.ID, &p.UserID, &p.Author, &avatar, &p.Content, &img, &p.Likes, &p.Club, &p.Timestamp); err != nil {
			return nil, err
		}
		if avatar.Valid {
			p.Avatar = &avatar.String
		}
		if img.Valid {
			p.Image = &img.String
		}
		var liked bool
		_ = r.db.QueryRowContext(ctx, `SELECT true FROM post_likes WHERE post_id = $1 AND user_id = $2`, p.ID, userID).Scan(&liked)
		p.Liked = liked
		comments, _ := r.commentsByPostID(ctx, p.ID)
		p.Comments = comments
		list = append(list, p)
	}
	return list, rows.Err()
}

func (r *PostRepository) GetByID(ctx context.Context, id, userID string) (*domain.Post, error) {
	var p domain.Post
	var avatar, img sql.NullString
	err := r.db.QueryRowContext(ctx,
		`SELECT id, user_id, author, avatar, content, image, likes, club, timestamp FROM posts WHERE id = $1`,
		id,
	).Scan(&p.ID, &p.UserID, &p.Author, &avatar, &p.Content, &img, &p.Likes, &p.Club, &p.Timestamp)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if avatar.Valid {
		p.Avatar = &avatar.String
	}
	if img.Valid {
		p.Image = &img.String
	}
	var liked bool
	_ = r.db.QueryRowContext(ctx, `SELECT true FROM post_likes WHERE post_id = $1 AND user_id = $2`, p.ID, userID).Scan(&liked)
	p.Liked = liked
	p.Comments, _ = r.commentsByPostID(ctx, p.ID)
	return &p, nil
}

func (r *PostRepository) Create(ctx context.Context, p *domain.Post) error {
	if p.ID == "" {
		p.ID = uuid.New().String()
	}
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO posts (id, user_id, author, avatar, content, image, likes, club, timestamp)
		 VALUES ($1, $2, $3, $4, $5, $6, 0, $7, $8)`,
		p.ID, p.UserID, p.Author, p.Avatar, p.Content, p.Image, p.Club, p.Timestamp,
	)
	return err
}

func (r *PostRepository) Update(ctx context.Context, p *domain.Post) error {
	res, err := r.db.ExecContext(ctx,
		`UPDATE posts SET author=$2, avatar=$3, content=$4, image=$5, club=$6, timestamp=$7 WHERE id=$1 AND user_id=$8`,
		p.ID, p.Author, p.Avatar, p.Content, p.Image, p.Club, p.Timestamp, p.UserID,
	)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *PostRepository) Delete(ctx context.Context, id, userID string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM posts WHERE id = $1 AND user_id = $2`, id, userID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *PostRepository) SetLiked(ctx context.Context, postID, userID string, liked bool) error {
	if liked {
		_, err := r.db.ExecContext(ctx,
			`INSERT INTO post_likes (post_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
			postID, userID,
		)
		if err != nil {
			return err
		}
		_, err = r.db.ExecContext(ctx, `UPDATE posts SET likes = likes + 1 WHERE id = $1`, postID)
		return err
	}
	_, err := r.db.ExecContext(ctx, `DELETE FROM post_likes WHERE post_id = $1 AND user_id = $2`, postID, userID)
	if err != nil {
		return err
	}
	_, err = r.db.ExecContext(ctx, `UPDATE posts SET likes = GREATEST(0, likes - 1) WHERE id = $1`, postID)
	return err
}

func (r *PostRepository) AddComment(ctx context.Context, postID string, c *domain.Comment) error {
	if c.ID == "" {
		c.ID = uuid.New().String()
	}
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO comments (id, post_id, author, avatar, content, timestamp) VALUES ($1, $2, $3, $4, $5, $6)`,
		c.ID, postID, c.Author, c.Avatar, c.Content, c.Timestamp,
	)
	return err
}

func (r *PostRepository) commentsByPostID(ctx context.Context, postID string) ([]domain.Comment, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT id, author, avatar, content, timestamp FROM comments WHERE post_id = $1 ORDER BY timestamp`,
		postID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	list := make([]domain.Comment, 0)
	for rows.Next() {
		var c domain.Comment
		var avatar sql.NullString
		if err := rows.Scan(&c.ID, &c.Author, &avatar, &c.Content, &c.Timestamp); err != nil {
			return nil, err
		}
		if avatar.Valid {
			c.Avatar = &avatar.String
		}
		c.PostID = postID
		list = append(list, c)
	}
	return list, rows.Err()
}
