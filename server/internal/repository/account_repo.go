package repository

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/adventure-game/server/internal/model"
)

type AccountRepo struct {
	db *sql.DB
}

func NewAccountRepo(db *sql.DB) *AccountRepo {
	return &AccountRepo{db: db}
}

func (r *AccountRepo) Create(ctx context.Context, account *model.Account) error {
	return r.db.QueryRowContext(ctx,
		`INSERT INTO accounts (phone, email, password_hash, quick_code) VALUES ($1, $2, $3, $4) RETURNING id, created_at`,
		account.Phone, account.Email, account.PasswordHash, account.QuickCode,
	).Scan(&account.ID, &account.CreatedAt)
}

func (r *AccountRepo) FindByPhone(ctx context.Context, phone string) (*model.Account, error) {
	a := &model.Account{}
	err := r.db.QueryRowContext(ctx,
		`SELECT id, phone, email, password_hash, quick_code, created_at FROM accounts WHERE phone = $1`, phone,
	).Scan(&a.ID, &a.Phone, &a.Email, &a.PasswordHash, &a.QuickCode, &a.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("find by phone: %w", err)
	}
	return a, nil
}

func (r *AccountRepo) FindByEmail(ctx context.Context, email string) (*model.Account, error) {
	a := &model.Account{}
	err := r.db.QueryRowContext(ctx,
		`SELECT id, phone, email, password_hash, quick_code, created_at FROM accounts WHERE email = $1`, email,
	).Scan(&a.ID, &a.Phone, &a.Email, &a.PasswordHash, &a.QuickCode, &a.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("find by email: %w", err)
	}
	return a, nil
}

func (r *AccountRepo) FindByID(ctx context.Context, id int64) (*model.Account, error) {
	a := &model.Account{}
	err := r.db.QueryRowContext(ctx,
		`SELECT id, phone, email, password_hash, quick_code, created_at FROM accounts WHERE id = $1`, id,
	).Scan(&a.ID, &a.Phone, &a.Email, &a.PasswordHash, &a.QuickCode, &a.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("find by id: %w", err)
	}
	return a, nil
}
