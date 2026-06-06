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

// GetSkillsData returns skill_tickets, total_pulls, skill_slots, and skills JSONB.
func (r *SkillRepo) GetSkillsData(ctx context.Context, charID int64) (skillTickets int64, totalPulls int, skillSlotsJSON string, skillsJSON string, err error) {
	err = r.db.QueryRowContext(ctx,
		`SELECT skill_tickets, COALESCE((equipments->>'total_pulls')::int, 0), COALESCE(skill_slots::text, '{}'), COALESCE(skills::text, '{}') FROM characters WHERE id=$1`,
		charID,
	).Scan(&skillTickets, &totalPulls, &skillSlotsJSON, &skillsJSON)
	return
}

// GetSkillsDataForUpdate locks the row and returns skill data.
func (r *SkillRepo) GetSkillsDataForUpdate(ctx context.Context, tx *sql.Tx, charID int64) (skillTickets int64, totalPulls int, skillSlotsJSON string, skillsJSON string, err error) {
	err = tx.QueryRowContext(ctx,
		`SELECT skill_tickets, COALESCE((equipments->>'total_pulls')::int, 0), COALESCE(skill_slots::text, '{}'), COALESCE(skills::text, '{}') FROM characters WHERE id=$1 FOR UPDATE`,
		charID,
	).Scan(&skillTickets, &totalPulls, &skillSlotsJSON, &skillsJSON)
	return
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

// UpdateSkills updates skill_tickets, total_pulls, and skills JSONB.
func (r *SkillRepo) UpdateSkills(ctx context.Context, charID int64, skillTickets int64, totalPulls int, skillsJSON string) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE characters SET skill_tickets=$1, equipments=jsonb_set(COALESCE(equipments, '{}'::jsonb), '{total_pulls}', to_jsonb($2::int)), skills=$3::jsonb WHERE id=$4`,
		skillTickets, totalPulls, skillsJSON, charID,
	)
	return err
}

// UpdateSkillsInTx updates skills within a transaction.
func (r *SkillRepo) UpdateSkillsInTx(ctx context.Context, tx *sql.Tx, charID int64, skillTickets int64, totalPulls int, skillsJSON string) error {
	_, err := tx.ExecContext(ctx,
		`UPDATE characters SET skill_tickets=$1, equipments=jsonb_set(COALESCE(equipments, '{}'::jsonb), '{total_pulls}', to_jsonb($2::int)), skills=$3::jsonb WHERE id=$4`,
		skillTickets, totalPulls, skillsJSON, charID,
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

// UpdateSkillItem updates a single skill in the skills JSONB by ID.
func (r *SkillRepo) UpdateSkillItem(ctx context.Context, charID int64, skillsJSON string) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE characters SET skills=$1::jsonb WHERE id=$2`,
		skillsJSON, charID,
	)
	return err
}
