package migrations

import (
	"database/sql"
	"embed"
)

//go:embed sql/*.sql
var fs embed.FS

func Run(db *sql.DB) error {
	data, err := fs.ReadFile("sql/001_init.up.sql")
	if err != nil {
		return err
	}
	_, err = db.Exec(string(data))
	return err
}
