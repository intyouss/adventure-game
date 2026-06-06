package repository

import (
	"context"
	"database/sql"
	"fmt"
)

type EquipmentRepo struct {
	db *sql.DB
}

func NewEquipmentRepo(db *sql.DB) *EquipmentRepo {
	return &EquipmentRepo{db: db}
}

// GetEquipments returns the raw JSONB for a character's equipment columns.
func (r *EquipmentRepo) GetEquipments(ctx context.Context, charID int64) (equipmentsJSON, equippedJSON string, gold int64, err error) {
	err = r.db.QueryRowContext(ctx,
		`SELECT equipments, equipped, gold FROM characters WHERE id = $1`, charID,
	).Scan(&equipmentsJSON, &equippedJSON, &gold)
	if err == sql.ErrNoRows {
		return "", "", 0, nil
	}
	if err != nil {
		return "", "", 0, fmt.Errorf("get equipments: %w", err)
	}
	return
}

// UpdateEquipments updates the JSONB columns and gold.
func (r *EquipmentRepo) UpdateEquipments(ctx context.Context, charID int64, equipmentsJSON, equippedJSON string, gold int64) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE characters SET equipments=$1, equipped=$2, gold=$3, updated_at=NOW() WHERE id=$4`,
		equipmentsJSON, equippedJSON, gold, charID,
	)
	return err
}

// AddEquipment appends an equipment to the character's inventory JSONB array.
func (r *EquipmentRepo) AddEquipment(ctx context.Context, charID int64, equipmentJSON string) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE characters SET equipments = equipments || $1::jsonb, updated_at=NOW() WHERE id=$2`,
		equipmentJSON, charID,
	)
	return err
}
