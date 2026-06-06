package repository

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/adventure-game/server/internal/model"
)

type CharacterRepo struct {
	db *sql.DB
}

func NewCharacterRepo(db *sql.DB) *CharacterRepo {
	return &CharacterRepo{db: db}
}

func (r *CharacterRepo) Create(ctx context.Context, c *model.Character) error {
	return r.db.QueryRowContext(ctx,
		`INSERT INTO characters (account_id, class, nickname, level, exp, gold, skill_tickets, chest_count, zone_level, stage_chapter, stage_level)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		 RETURNING id, created_at, updated_at`,
		c.AccountID, c.Class, c.Nickname, c.Level, c.Exp, c.Gold, c.SkillTickets, c.ChestCount, c.ZoneLevel, c.StageChapter, c.StageLevel,
	).Scan(&c.ID, &c.CreatedAt, &c.UpdatedAt)
}

func (r *CharacterRepo) FindByAccountID(ctx context.Context, accountID int64) (*model.Character, error) {
	c := &model.Character{}
	err := r.db.QueryRowContext(ctx,
		`SELECT id, account_id, class, nickname, level, exp, gold, skill_tickets, chest_count, zone_level, stage_chapter, stage_level, created_at, updated_at
		 FROM characters WHERE account_id = $1`, accountID,
	).Scan(&c.ID, &c.AccountID, &c.Class, &c.Nickname, &c.Level, &c.Exp, &c.Gold, &c.SkillTickets, &c.ChestCount, &c.ZoneLevel, &c.StageChapter, &c.StageLevel, &c.CreatedAt, &c.UpdatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("find by account id: %w", err)
	}
	return c, nil
}

func (r *CharacterRepo) FindByID(ctx context.Context, id int64) (*model.Character, error) {
	c := &model.Character{}
	err := r.db.QueryRowContext(ctx,
		`SELECT id, account_id, class, nickname, level, exp, gold, skill_tickets, chest_count, zone_level, stage_chapter, stage_level, created_at, updated_at
		 FROM characters WHERE id = $1`, id,
	).Scan(&c.ID, &c.AccountID, &c.Class, &c.Nickname, &c.Level, &c.Exp, &c.Gold, &c.SkillTickets, &c.ChestCount, &c.ZoneLevel, &c.StageChapter, &c.StageLevel, &c.CreatedAt, &c.UpdatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("find by id: %w", err)
	}
	return c, nil
}

// FindByIDForUpdate locks the character row for atomic updates.
func (r *CharacterRepo) FindByIDForUpdate(ctx context.Context, tx *sql.Tx, id int64) (*model.Character, error) {
	c := &model.Character{}
	err := tx.QueryRowContext(ctx,
		`SELECT id, account_id, class, nickname, level, exp, gold, skill_tickets, chest_count, zone_level, stage_chapter, stage_level, created_at, updated_at
		 FROM characters WHERE id = $1 FOR UPDATE`, id,
	).Scan(&c.ID, &c.AccountID, &c.Class, &c.Nickname, &c.Level, &c.Exp, &c.Gold, &c.SkillTickets, &c.ChestCount, &c.ZoneLevel, &c.StageChapter, &c.StageLevel, &c.CreatedAt, &c.UpdatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("find by id for update: %w", err)
	}
	return c, nil
}

func (r *CharacterRepo) UpdateStats(ctx context.Context, c *model.Character) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE characters SET level=$1, exp=$2, gold=$3, skill_tickets=$4, stage_chapter=$5, stage_level=$6, updated_at=NOW()
		 WHERE id=$7`,
		c.Level, c.Exp, c.Gold, c.SkillTickets, c.StageChapter, c.StageLevel, c.ID,
	)
	return err
}

// UpdateStatsInTx updates stats within a transaction.
func (r *CharacterRepo) UpdateStatsInTx(ctx context.Context, tx *sql.Tx, c *model.Character) error {
	_, err := tx.ExecContext(ctx,
		`UPDATE characters SET level=$1, exp=$2, gold=$3, skill_tickets=$4, stage_chapter=$5, stage_level=$6, updated_at=NOW()
		 WHERE id=$7`,
		c.Level, c.Exp, c.Gold, c.SkillTickets, c.StageChapter, c.StageLevel, c.ID,
	)
	return err
}

func (r *CharacterRepo) UpdateChestFields(ctx context.Context, charID int64, chestCount, zoneLevel int, gold int64) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE characters SET chest_count=$1, zone_level=$2, gold=$3, updated_at=NOW() WHERE id=$4`,
		chestCount, zoneLevel, gold, charID,
	)
	return err
}

// UpdateChestFieldsInTx updates chest fields within a transaction.
func (r *CharacterRepo) UpdateChestFieldsInTx(ctx context.Context, tx *sql.Tx, charID int64, chestCount, zoneLevel int, gold int64) error {
	_, err := tx.ExecContext(ctx,
		`UPDATE characters SET chest_count=$1, zone_level=$2, gold=$3, updated_at=NOW() WHERE id=$4`,
		chestCount, zoneLevel, gold, charID,
	)
	return err
}

// UpdateStageProgress updates only stage progress columns.
func (r *CharacterRepo) UpdateStageProgress(ctx context.Context, charID int64, chapter, level int) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE characters SET stage_chapter=$1, stage_level=$2, updated_at=NOW() WHERE id=$3`,
		chapter, level, charID,
	)
	return err
}

// DeductGold atomically deducts gold from a character.
func (r *CharacterRepo) DeductGold(ctx context.Context, charID int64, amount int64) error {
	result, err := r.db.ExecContext(ctx,
		`UPDATE characters SET gold = gold - $1 WHERE id = $2 AND gold >= $1`,
		amount, charID,
	)
	if err != nil {
		return fmt.Errorf("deduct gold: %w", err)
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("insufficient gold")
	}
	return nil
}

// InsertCurrencyLog writes a currency transaction log entry.
func (r *CharacterRepo) InsertCurrencyLog(ctx context.Context, charID int64, currency string, amount int64, reason string) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO currency_logs (character_id, currency, amount, reason) VALUES ($1, $2, $3, $4)`,
		charID, currency, amount, reason,
	)
	return err
}
