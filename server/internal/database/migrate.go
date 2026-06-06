package database

import (
	"database/sql"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

func RunMigrations(db *sql.DB, migrationsDir string) error {
	entries, err := os.ReadDir(migrationsDir)
	if err != nil {
		return fmt.Errorf("read migrations dir: %w", err)
	}

	// Create migration tracking table
	if _, err := db.Exec(`CREATE TABLE IF NOT EXISTS schema_migrations (
		version VARCHAR(255) PRIMARY KEY,
		applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
	)`); err != nil {
		return fmt.Errorf("create migrations table: %w", err)
	}

	// Collect .up.sql files
	var upFiles []string
	for _, e := range entries {
		if strings.HasSuffix(e.Name(), ".up.sql") {
			upFiles = append(upFiles, e.Name())
		}
	}
	sort.Strings(upFiles)

	for _, f := range upFiles {
		version := strings.TrimSuffix(f, ".up.sql")

		var exists bool
		err := db.QueryRow(`SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version = $1)`, version).Scan(&exists)
		if err != nil {
			return fmt.Errorf("check migration %s: %w", version, err)
		}
		if exists {
			slog.Info("migration already applied", "version", version)
			continue
		}

		content, err := os.ReadFile(filepath.Join(migrationsDir, f))
		if err != nil {
			return fmt.Errorf("read migration file %s: %w", f, err)
		}

		tx, err := db.Begin()
		if err != nil {
			return fmt.Errorf("begin tx for %s: %w", version, err)
		}

		if _, err := tx.Exec(string(content)); err != nil {
			tx.Rollback()
			return fmt.Errorf("execute migration %s: %w", version, err)
		}

		if _, err := tx.Exec(`INSERT INTO schema_migrations (version) VALUES ($1)`, version); err != nil {
			tx.Rollback()
			return fmt.Errorf("record migration %s: %w", version, err)
		}

		if err := tx.Commit(); err != nil {
			return fmt.Errorf("commit migration %s: %w", version, err)
		}

		slog.Info("migration applied", "version", version)
	}

	return nil
}
