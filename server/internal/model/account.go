package model

import "time"

type Account struct {
	ID           int64     `json:"id"           db:"id"`
	Phone        string    `json:"phone"        db:"phone"`
	Email        string    `json:"email"        db:"email"`
	PasswordHash string    `json:"-"            db:"password_hash"`
	CreatedAt    time.Time `json:"created_at"   db:"created_at"`
}
