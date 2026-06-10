package model

import "testing"

func TestGenerateStageConfig(t *testing.T) {
	cfg := GenerateStageConfig(1, 1)
	if cfg.StageID != "1-1" {
		t.Errorf("StageID = %s, want 1-1", cfg.StageID)
	}
	if cfg.Chapter != 1 || cfg.Level != 1 {
		t.Errorf("Chapter/Level = %d/%d, want 1/1", cfg.Chapter, cfg.Level)
	}
	if len(cfg.Waves) != 5 {
		t.Errorf("Waves = %d, want 5", len(cfg.Waves))
	}
	if !cfg.Waves[4].IsBoss {
		t.Error("Wave 5 should be boss")
	}
	if cfg.Waves[0].IsBoss {
		t.Error("Wave 1 should not be boss")
	}
}

func TestGenerateStageConfigScaling(t *testing.T) {
	cfg1 := GenerateStageConfig(1, 1)
	cfg10 := GenerateStageConfig(5, 10)

	if cfg1.Waves[0].Monsters[0].HP >= cfg10.Waves[0].Monsters[0].HP {
		t.Error("Later stages should have higher monster HP")
	}
}

func TestCalculateRewards(t *testing.T) {
	r := CalculateRewards(1, 1)
	if r.Gold != 0 {
		t.Error("Stage rewards should not give gold (gold only from decompose)")
	}
	if r.SkillTickets <= 0 || r.Chests <= 0 {
		t.Error("SkillTickets and Chests should be positive")
	}

	rBoss := CalculateRewards(1, 10)
	if rBoss.SkillTickets <= r.SkillTickets {
		t.Error("Boss level should give more skill tickets")
	}
	if rBoss.Chests < r.Chests {
		t.Error("Boss level should give more chests")
	}
}
