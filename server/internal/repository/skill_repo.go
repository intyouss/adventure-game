package repository

import (
	"context"
	"database/sql"
	"fmt"
)

type SkillRepo struct {
	db *sql.DB
}

func NewSkillRepo(db *sql.DB) *SkillRepo {
	return &SkillRepo{db: db}
}

// GetSkillData reads skill_tickets, total_pulls (from equipments JSONB), and skill_slots.
func (r *SkillRepo) GetSkillData(ctx context.Context, charID int64) (skillTickets int64, totalPulls int, skillSlotsJSON string, err error) {
	err = r.db.QueryRowContext(ctx,
		`SELECT skill_tickets, COALESCE((equipments->>'total_pulls')::int, 0), COALESCE(skill_slots::text, '{}') FROM characters WHERE id=$1`,
		charID,
	).Scan(&skillTickets, &totalPulls, &skillSlotsJSON)
	return
}

// UpdateAfterPull updates skill_tickets, skill_slots, and total_pulls after a gacha pull.
func (r *SkillRepo) UpdateAfterPull(ctx context.Context, charID int64, skillTickets int64, totalPulls int, skillSlotsJSON string) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE characters SET skill_tickets=$1, skill_slots=$2::jsonb, equipments=jsonb_set(COALESCE(equipments, '{}'::jsonb), '{total_pulls}', to_jsonb($3::int)) WHERE id=$4`,
		skillTickets, skillSlotsJSON, totalPulls, charID,
	)
	return err
}

// UpdateSkillSlots updates only the skill_slots column.
func (r *SkillRepo) UpdateSkillSlots(ctx context.Context, charID int64, skillSlotsJSON string) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE characters SET skill_slots=$1::jsonb WHERE id=$2`,
		skillSlotsJSON, charID,
	)
	return err
}

// DeductTickets atomically deducts skill tickets.
func (r *SkillRepo) DeductTickets(ctx context.Context, charID int64, amount int64) error {
	result, err := r.db.ExecContext(ctx,
		`UPDATE characters SET skill_tickets = skill_tickets - $1 WHERE id=$2 AND skill_tickets >= $1`,
		amount, charID,
	)
	if err != nil {
		return fmt.Errorf("deduct tickets: %w", err)
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return fmt.Errorf("insufficient skill tickets")
	}
	return nil
}
