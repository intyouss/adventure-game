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
// Checks ALL 7 dimensions: damage_tolerance, time_tolerance, wave_count,
// boss_defeated, skill_usage_range, hp_remaining_range, monster_kill_count.
func (s *BattleService) PlanA(summary model.BattleSummary, stageCfg model.StageConfig) model.PlanAResult {
	// 1. Wave count match
	if len(summary.Waves) != len(stageCfg.Waves) {
		return model.PlanAResult{Passed: false, Reason: "wave count mismatch"}
	}

	// 2. Wave order
	for i, w := range summary.Waves {
		if w.Wave != i+1 {
			return model.PlanAResult{Passed: false, Reason: "wave order mismatch"}
		}
	}

	// 3. Clear time tolerance: must not be impossibly fast (2s per wave minimum, 80% tolerance)
	theoreticalMinMs := len(stageCfg.Waves) * 2000
	if summary.ClearTimeMs < theoreticalMinMs*80/100 {
		return model.PlanAResult{Passed: false, Reason: "clear time too fast"}
	}

	// 4. Damage tolerance: total damage must not exceed player's theoretical max
	playerDPS := float64(summary.PlayerStats.ATK) * summary.PlayerStats.AtkSpeed
	critBonus := summary.PlayerStats.CritRate * (summary.PlayerStats.CritDmg - 1.0)
	maxDPS := playerDPS * (1.0 + critBonus)
	maxDamage := maxDPS * float64(summary.ClearTimeMs)/1000.0 * 1.2
	if summary.TotalDamageDealt > maxDamage {
		return model.PlanAResult{Passed: false, Reason: "damage exceeds theoretical max"}
	}

	// 5. Boss defeated check: if last wave is boss, must be defeated
	for _, wave := range stageCfg.Waves {
		if wave.IsBoss {
			if !summary.BossDefeated {
				return model.PlanAResult{Passed: false, Reason: "boss not defeated"}
			}
		}
	}

	// 6. Skill usage range: must be within reasonable bounds
	totalCasts := 0
	for _, count := range summary.SkillCastCounts {
		totalCasts += count
	}
	maxExpectedCasts := (summary.ClearTimeMs / 1000) * 2 // max 2 casts per second
	if totalCasts > maxExpectedCasts+5 {
		return model.PlanAResult{Passed: false, Reason: "skill usage exceeds max"}
	}

	// 7. HP remaining: HPBefore - TotalDamageTaken should match HPAfter within tolerance
	expectedHPAfter := summary.HPBefore - summary.TotalDamageTaken
	if summary.HPAfter < 0 {
		summary.HPAfter = 0
	}
	hpDiff := expectedHPAfter - summary.HPAfter
	if hpDiff < 0 {
		hpDiff = -hpDiff
	}
	hpTolerance := float64(summary.PlayerStats.HP) * 0.02 // 2% of max HP
	if float64(hpDiff) > float64(hpTolerance) {
		return model.PlanAResult{Passed: false, Reason: "HP remaining mismatch"}
	}

	// 8. Monster kill count: total kills must match expected monsters
	expectedKills := 0
	for _, wave := range stageCfg.Waves {
		for _, m := range wave.Monsters {
			expectedKills += m.Count
		}
	}
	if summary.MonsterKills < expectedKills*80/100 { // at least 80% kills
		return model.PlanAResult{Passed: false, Reason: "monster kill count too low"}
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
		// On success, calculate rewards
		chapter, level := parseStage(summary.StageID)
		rewards := model.CalculateRewards(chapter, level)
		return model.PlanBResult{Passed: true, HPDiffPct: diff, Rewards: &rewards}
	}
	return model.PlanBResult{Passed: false, HPDiffPct: diff, Reason: "HP difference exceeds 5% tolerance"}
}

// parseStage extracts chapter and level from stage_id like "1-5".
func parseStage(stageID string) (int, int) {
	var chapter, level int
	fmt.Sscanf(stageID, "%d-%d", &chapter, &level)
	if chapter < 1 {
		chapter = 1
	}
	if level < 1 {
		level = 1
	}
	return chapter, level
}
