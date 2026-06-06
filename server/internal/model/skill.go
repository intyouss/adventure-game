package model

// Skill represents a skill owned by a player.
type Skill struct {
	ID      string  `json:"id"`
	Name    string  `json:"name"`
	Quality int     `json:"quality"`
	Level   int     `json:"level"`
	Cards   int     `json:"cards"`   // duplicate cards for upgrading
	Coeff   float64 `json:"coeff"`   // skill damage coefficient
}

// SkillConfig defines a skill template.
type SkillConfig struct {
	ID        string  `json:"id"`
	Name      string  `json:"name"`
	Quality   int     `json:"quality"`
	BaseCoeff float64 `json:"base_coeff"`
}

// Initial skill pool (v1: 8 skills across 4 qualities).
var SkillPool = []SkillConfig{
	{ID: "s-fireball", Name: "火球术", Quality: 1, BaseCoeff: 1.2},
	{ID: "s-icebolt", Name: "冰锥术", Quality: 1, BaseCoeff: 1.1},
	{ID: "s-thunder", Name: "雷电术", Quality: 2, BaseCoeff: 1.5},
	{ID: "s-heal", Name: "治愈术", Quality: 2, BaseCoeff: 0.0},
	{ID: "s-meteor", Name: "陨石术", Quality: 3, BaseCoeff: 2.0},
	{ID: "s-blizzard", Name: "暴风雪", Quality: 3, BaseCoeff: 1.8},
	{ID: "s-holylight", Name: "圣光", Quality: 4, BaseCoeff: 2.5},
	{ID: "s-dragonfire", Name: "龙息", Quality: 4, BaseCoeff: 3.0},
}
