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
		`INSERT INTO characters (account_id, class, nickname, level, exp, gold, skill_tickets)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)
		 RETURNING id, created_at, updated_at`,
		c.AccountID, c.Class, c.Nickname, c.Level, c.Exp, c.Gold, c.SkillTickets,
	).Scan(&c.ID, &c.CreatedAt, &c.UpdatedAt)
}

func (r *CharacterRepo) FindByAccountID(ctx context.Context, accountID int64) (*model.Character, error) {
	c := &model.Character{}
	err := r.db.QueryRowContext(ctx,
		`SELECT id, account_id, class, nickname, level, exp, gold, skill_tickets, created_at, updated_at
		 FROM characters WHERE account_id = $1`, accountID,
	).Scan(&c.ID, &c.AccountID, &c.Class, &c.Nickname, &c.Level, &c.Exp, &c.Gold, &c.SkillTickets, &c.CreatedAt, &c.UpdatedAt)
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
		`SELECT id, account_id, class, nickname, level, exp, gold, skill_tickets, created_at, updated_at
		 FROM characters WHERE id = $1`, id,
	).Scan(&c.ID, &c.AccountID, &c.Class, &c.Nickname, &c.Level, &c.Exp, &c.Gold, &c.SkillTickets, &c.CreatedAt, &c.UpdatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("find by id: %w", err)
	}
	return c, nil
}

func (r *CharacterRepo) UpdateStats(ctx context.Context, c *model.Character) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE characters SET level=$1, exp=$2, gold=$3, skill_tickets=$4, updated_at=NOW()
		 WHERE id=$5`,
		c.Level, c.Exp, c.Gold, c.SkillTickets, c.ID,
	)
	return err
}
