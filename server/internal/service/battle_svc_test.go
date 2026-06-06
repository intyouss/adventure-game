package service

import (
	"testing"

	"github.com/adventure-game/server/internal/model"
)

func TestPlanAWaveCountMismatch(t *testing.T) {
	svc := NewBattleService(nil)
	summary := model.BattleSummary{Waves: []model.WaveResult{{Wave: 1}}}
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
		PlayerStats: model.PlayerBattleStats{ATK: 10, AtkSpeed: 1.0, CritRate: 0, CritDmg: 1.5},
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
		TotalDamageDealt: 300,
		PlayerStats:      model.PlayerBattleStats{ATK: 10, AtkSpeed: 1.0, CritRate: 0, CritDmg: 1.5},
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
		TotalDamageTaken: 29,
		PlayerStats:      model.PlayerBattleStats{HP: 100, DEF: 5},
	}
	cfg := model.StageConfig{
		Waves: []model.WaveConfig{
			{Monsters: []model.MonsterConfig{{Count: 3, ATK: 10, DEF: 2}}},
		},
	}

	result := svc.Simulate(summary, cfg)
	if !result.Passed {
		t.Errorf("Should pass: %s (diff=%f)", result.Reason, result.HPDiffPct)
	}
}
