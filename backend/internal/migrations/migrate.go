// backend/internal/migrations/migrate.go
package migrations

import (
	"database/sql"
	"embed"
	"fmt"
	"sort"
)

//go:embed sql/*.sql
var fs embed.FS

func Run(db *sql.DB) error {
	// Создаем таблицу для отслеживания миграций
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version TEXT PRIMARY KEY,
			applied_at TIMESTAMPTZ DEFAULT NOW()
		)
	`)
	if err != nil {
		return fmt.Errorf("create migrations table: %w", err)
	}

	// Получаем список всех .up.sql файлов
	entries, err := fs.ReadDir("sql")
	if err != nil {
		return err
	}

	var migrations []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if len(name) > 7 && name[len(name)-7:] == ".up.sql" {
			migrations = append(migrations, name)
		}
	}
	sort.Strings(migrations)

	// Применяем миграции по порядку
	for _, migration := range migrations {
		// Проверяем, применена ли уже эта миграция
		var applied bool
		err = db.QueryRow("SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version = $1)", migration).Scan(&applied)
		if err != nil {
			return fmt.Errorf("check migration %s: %w", migration, err)
		}
		if applied {
			continue
		}

		// Читаем и применяем миграцию
		data, err := fs.ReadFile("sql/" + migration)
		if err != nil {
			return fmt.Errorf("read migration %s: %w", migration, err)
		}

		_, err = db.Exec(string(data))
		if err != nil {
			return fmt.Errorf("apply migration %s: %w", migration, err)
		}

		// Отмечаем как применённую
		_, err = db.Exec("INSERT INTO schema_migrations (version) VALUES ($1)", migration)
		if err != nil {
			return fmt.Errorf("mark migration %s: %w", migration, err)
		}

		fmt.Printf("Applied migration: %s\n", migration)
	}

	return nil
}
