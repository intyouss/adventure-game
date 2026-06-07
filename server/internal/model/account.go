package model

import (
	"database/sql"
	"time"
)

type Account struct {
	ID           int64          `json:"id"           db:"id"`
	Phone        sql.NullString `json:"phone"        db:"phone"`
	Email        sql.NullString `json:"email"        db:"email"`
	PasswordHash string         `json:"-"            db:"password_hash"`
	QuickCode    sql.NullString `json:"-"            db:"quick_code"`
	CreatedAt    time.Time      `json:"created_at"   db:"created_at"`
}

func (a *Account) PhoneStr() string {
	if a.Phone.Valid {
		return a.Phone.String
	}
	return ""
}

func (a *Account) EmailStr() string {
	if a.Email.Valid {
		return a.Email.String
	}
	return ""
}
