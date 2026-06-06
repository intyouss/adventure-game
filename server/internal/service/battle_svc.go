package service

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/redis/go-redis/v9"

	"github.com/adventure-game/server/internal/model"
)

type BattleService struct {
	rdb *redis.Client
}

func NewBattleService(rdb *redis.Client) *BattleService {
	return &BattleService{rdb: rdb}
}

// PlanA runs quick validation checks on the battle summary.
func (s *BattleService) PlanA(summary model.BattleSummary, stageCfg model.StageConfig) model.PlanAResult {
	// Check wave count
	if len(summary.Waves) != len(stageCfg.Waves) {
		return model.PlanAResult{Passed: false, Reason: "wave count mismatch"}
	}

	// Check wave order
	for i, w := range summary.Waves {
		if w.Wave != i+1 {
			return model.PlanAResult{Passed: false, Reason: "wave order mismatch"}
		}
	}

	// Check clear time: must not be impossibly fast
	theoreticalMinMs := len(stageCfg.Waves) * 2000 // at least 2s per wave
	if summary.ClearTimeMs < theoreticalMinMs*80/100 {
		return model.PlanAResult{Passed: false, Reason: "clear time too fast"}
	}

	// Check total damage is within player's theoretical max
	playerDPS := float64(summary.PlayerStats.ATK) * summary.PlayerStats.AtkSpeed
	critBonus := summary.PlayerStats.CritRate * (summary.PlayerStats.CritDmg - 1.0)
	maxDPS := playerDPS * (1.0 + critBonus)
	maxDamage := maxDPS * float64(summary.ClearTimeMs)/1000.0 * 1.2
	if summary.TotalDamageDealt > maxDamage {
		return model.PlanAResult{Passed: false, Reason: "damage exceeds theoretical max"}
	}

	return model.PlanAResult{Passed: true}
}

// PlanB enqueues the battle summary for async server-side simulation via Redis Streams.
func (s *BattleService) PlanB(ctx context.Context, summary model.BattleSummary) error {
	data, err := json.Marshal(summary)
	if err != nil {
		return fmt.Errorf("marshal summary: %w", err)
	}
	return s.rdb.XAdd(ctx, &redis.XAddArgs{
		Stream: "battle:planb",
		Values: map[string]interface{}{"summary": string(data)},
	}).Err()
}

// Simulate runs a simplified server-side battle simulation for Plan B.
func (s *BattleService) Simulate(summary model.BattleSummary, stageCfg model.StageConfig) model.PlanBResult {
	playerHP := float64(summary.PlayerStats.HP)
	totalMonsterDamage := 0.0

	for _, wave := range stageCfg.Waves {
		for _, m := range wave.Monsters {
			rawDamage := float64(m.ATK) * float64(m.Count)
			defReduction := float64(summary.PlayerStats.DEF) * 0.3
			actual := rawDamage - defReduction
			if actual < rawDamage*0.1 {
				actual = rawDamage * 0.1
			}
			totalMonsterDamage += actual
		}
	}

	hpLost := totalMonsterDamage
	if hpLost > playerHP {
		hpLost = playerHP
	}
	hpLostPct := hpLost / playerHP

	clientHPLostPct := summary.TotalDamageTaken / playerHP
	diff := hpLostPct - clientHPLostPct
	if diff < 0 {
		diff = -diff
	}

	if diff < 0.05 {
		return model.PlanBResult{Passed: true, HPDiffPct: diff}
	}
	return model.PlanBResult{Passed: false, HPDiffPct: diff, Reason: "HP difference exceeds 5% tolerance"}
}
