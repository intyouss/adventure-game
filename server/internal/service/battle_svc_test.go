package service

import (
	"testing"

	"github.com/adventure-game/server/internal/model"
)

func TestPlanAWaveCountMismatch(t *testing.T) {
	svc := NewBattleService(nil)
	summary := model.BattleSummary{
		Waves:        []model.WaveResult{{Wave: 1}},
		HPBefore:     100,
		HPAfter:      99,
		BossDefeated: true,
		MonsterKills: 15,
		ClearTimeMs:  30000,
		PlayerStats:  model.PlayerBattleStats{ATK: 10, DEF: 5, HP: 100, AtkSpeed: 1.0, CritRate: 0, CritDmg: 1.5},
	}
	cfg := model.StageConfig{Waves: make([]model.WaveConfig, 5)}

	result := svc.PlanA(summary, cfg)
	if result.Passed {
		t.Error("Should reject wave count mismatch")
	}
}

func TestPlanATooFast(t *testing.T) {
	svc := NewBattleService(nil)
	summary := model.BattleSummary{
		ClearTimeMs: 100,
		HPBefore:    100,
		HPAfter:     99,
		BossDefeated: true,
		MonsterKills: 15,
		PlayerStats: model.PlayerBattleStats{ATK: 10, AtkSpeed: 1.0, CritRate: 0, CritDmg: 1.5, HP: 100},
		Waves:       []model.WaveResult{{Wave: 1}, {Wave: 2}, {Wave: 3}, {Wave: 4}, {Wave: 5}},
	}
	cfg := model.StageConfig{Waves: make([]model.WaveConfig, 5)}

	result := svc.PlanA(summary, cfg)
	if result.Passed {
		t.Error("Should reject impossibly fast clear time")
	}
}

func TestPlanAPass(t *testing.T) {
	svc := NewBattleService(nil)
	summary := model.BattleSummary{
		ClearTimeMs:      30000,
		TotalDamageDealt: 200,
		HPBefore:         100,
		HPAfter:          99,
		BossDefeated:     true,
		MonsterKills:     15,
		PlayerStats:      model.PlayerBattleStats{ATK: 10, AtkSpeed: 1.0, CritRate: 0, CritDmg: 1.5, HP: 100, DEF: 5},
		Waves:            []model.WaveResult{{Wave: 1}, {Wave: 2}, {Wave: 3}, {Wave: 4}, {Wave: 5}},
	}
	cfg := model.StageConfig{Waves: make([]model.WaveConfig, 5)}

	result := svc.PlanA(summary, cfg)
	if !result.Passed {
		t.Errorf("Should pass: %s", result.Reason)
	}
}

func TestSimulateHPWithinTolerance(t *testing.T) {
	svc := NewBattleService(nil)
	summary := model.BattleSummary{
		TotalDamageTaken: 5,
		HPBefore:         100,
		HPAfter:          95,
		BossDefeated:     true,
		MonsterKills:     3,
		PlayerStats:      model.PlayerBattleStats{HP: 100, DEF: 50, ATK: 10, AtkSpeed: 1.0, CritRate: 0, CritDmg: 1.5},
		Waves:            []model.WaveResult{{Wave: 1, IsBoss: false}, {Wave: 2, IsBoss: true}},
	}
	cfg := model.StageConfig{
		Waves: []model.WaveConfig{
			{Monsters: []model.MonsterConfig{{Count: 3, ATK: 5, DEF: 2, HP: 30}}},
			{IsBoss: true, Monsters: []model.MonsterConfig{{Count: 1, ATK: 5, DEF: 3, HP: 50}}},
		},
	}

	result := svc.Simulate(summary, cfg)
	if !result.Passed {
		t.Errorf("Should pass: %s (diff=%f)", result.Reason, result.HPDiffPct)
	}
}
