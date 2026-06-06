package model

import "time"

type Character struct {
	ID           int64     `json:"id"            db:"id"`
	AccountID    int64     `json:"account_id"    db:"account_id"`
	Class        string    `json:"class"         db:"class"`
	Nickname     string    `json:"nickname"      db:"nickname"`
	Level        int       `json:"level"         db:"level"`
	Exp          int64     `json:"exp"           db:"exp"`
	Gold         int64     `json:"gold"          db:"gold"`
	SkillTickets int64     `json:"skill_tickets" db:"skill_tickets"`
	CreatedAt    time.Time `json:"created_at"    db:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"    db:"updated_at"`
}

// FinalStats represents a character's computed combat stats.
type FinalStats struct {
	ATK      int     `json:"atk"`
	DEF      int     `json:"def"`
	HP       int     `json:"hp"`
	CritRate float64 `json:"crit_rate"`
	CritDmg  float64 `json:"crit_dmg"`
	AtkSpeed float64 `json:"atk_speed"`
}

// Base stats at level 1 for warrior class.
var ClassBaseStats = map[string]FinalStats{
	"warrior": {ATK: 10, DEF: 5, HP: 100, CritRate: 0.05, CritDmg: 1.5, AtkSpeed: 1.0},
}

// Growth per level after level 1.
var ClassGrowth = map[string]FinalStats{
	"warrior": {ATK: 3, DEF: 1, HP: 20, CritRate: 0, CritDmg: 0, AtkSpeed: 0},
}
