package model

// BattleSummary is submitted by the client after a battle.
type BattleSummary struct {
	StageID          string            `json:"stage_id"`
	TotalDamageDealt float64           `json:"total_damage_dealt"`
	TotalDamageTaken float64           `json:"total_damage_taken"`
	ClearTimeMs      int               `json:"clear_time_ms"`
	Waves            []WaveResult      `json:"waves"`
	SkillsUsed       []string          `json:"skills_used"`
	SkillCastCounts  map[string]int    `json:"skill_cast_counts"`
	PlayerStats      PlayerBattleStats `json:"player_stats"`
	HPBefore         float64           `json:"hp_before"`
	HPAfter          float64           `json:"hp_after"`
	BossDefeated     bool              `json:"boss_defeated"`
	MonsterKills     int               `json:"monster_kills"`
}

type WaveResult struct {
	Wave        int     `json:"wave"`
	Kills       int     `json:"kills"`
	Damage      float64 `json:"damage"`
	DamageTaken float64 `json:"damage_taken"`
	IsBoss      bool    `json:"is_boss"`
}

type PlayerBattleStats struct {
	ATK      int     `json:"atk"`
	DEF      int     `json:"def"`
	HP       int     `json:"hp"`
	CritRate float64 `json:"crit_rate"`
	CritDmg  float64 `json:"crit_dmg"`
	AtkSpeed float64 `json:"atk_speed"`
}

// PlanAResult is the immediate validation result.
type PlanAResult struct {
	Passed bool   `json:"passed"`
	Reason string `json:"reason,omitempty"`
}

// PlanBResult is the async validation result.
type PlanBResult struct {
	Passed    bool          `json:"passed"`
	HPDiffPct float64       `json:"hp_diff_pct,omitempty"`
	Reason    string        `json:"reason,omitempty"`
	Rewards   *StageRewards `json:"rewards,omitempty"`
}

// BattleAnomaly records when Plan B fails.
type BattleAnomaly struct {
	CharacterID int64   `json:"character_id"`
	StageID     string  `json:"stage_id"`
	HPDiffPct   float64 `json:"hp_diff_pct"`
	Reason      string  `json:"reason"`
}

// BattleSettled contains the final settlement.
type BattleSettled struct {
	Passed  bool          `json:"passed"`
	Rewards *StageRewards `json:"rewards,omitempty"`
	Reason  string        `json:"reason,omitempty"`
}
