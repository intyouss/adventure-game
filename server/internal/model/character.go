package model

import (
	"math"
	"time"
)

type Character struct {
	ID           int64     `json:"id"            db:"id"`
	AccountID    int64     `json:"account_id"    db:"account_id"`
	Class        string    `json:"class"         db:"class"`
	Nickname     string    `json:"nickname"      db:"nickname"`
	Level        int       `json:"level"         db:"level"`
	Exp          int64     `json:"exp"           db:"exp"`
	Gold         int64     `json:"gold"          db:"gold"`
	SkillTickets int64     `json:"skill_tickets" db:"skill_tickets"`
	ChestCount   int       `json:"chest_count"   db:"chest_count"`
	ZoneLevel    int       `json:"zone_level"    db:"zone_level"`
	StageChapter int       `json:"stage_chapter"  db:"stage_chapter"`
	StageLevel   int       `json:"stage_level"    db:"stage_level"`
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

// ExpToNextLevel returns experience needed to reach the next level.
// Formula: 100 * 1.15^(level-1)
func ExpToNextLevel(level int) int64 {
	return int64(math.Round(100 * math.Pow(1.15, float64(level-1))))
}

// CalcCP computes Combat Power (CP).
// Formula: (ATK * 2 + DEF * 1.5 + HP * 0.5) * (1 + level * 0.1)
func CalcCP(stats FinalStats, level int) float64 {
	raw := float64(stats.ATK)*2.0 + float64(stats.DEF)*1.5 + float64(stats.HP)*0.5
	return math.Round(raw * (1.0 + float64(level)*0.1))
}

// MaxLevel is the maximum character level.
const MaxLevel = 150
