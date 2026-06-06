package service

import (
	"math"
	"testing"

	"github.com/adventure-game/server/internal/model"
)

func TestCalcStatsLevel1(t *testing.T) {
	svc := NewCharacterService(nil)
	c := &model.Character{Class: "warrior", Level: 1}
	stats := svc.CalcStats(c)

	if stats.ATK != 10 {
		t.Errorf("ATK = %d, want 10", stats.ATK)
	}
	if stats.DEF != 5 {
		t.Errorf("DEF = %d, want 5", stats.DEF)
	}
	if stats.HP != 100 {
		t.Errorf("HP = %d, want 100", stats.HP)
	}
	if stats.CritRate != 0.05 {
		t.Errorf("CritRate = %f, want 0.05", stats.CritRate)
	}
	if stats.CritDmg != 1.5 {
		t.Errorf("CritDmg = %f, want 1.5", stats.CritDmg)
	}
	if stats.AtkSpeed != 1.0 {
		t.Errorf("AtkSpeed = %f, want 1.0", stats.AtkSpeed)
	}
}

func TestCalcStatsLevel10(t *testing.T) {
	svc := NewCharacterService(nil)
	c := &model.Character{Class: "warrior", Level: 10}
	stats := svc.CalcStats(c)

	// Level 10 means 9 levels of growth
	// ATK: 10 + 3*9 = 37
	if stats.ATK != 37 {
		t.Errorf("ATK = %d, want 37", stats.ATK)
	}
	// DEF: 5 + 1*9 = 14
	if stats.DEF != 14 {
		t.Errorf("DEF = %d, want 14", stats.DEF)
	}
	// HP: 100 + 20*9 = 280
	if stats.HP != 280 {
		t.Errorf("HP = %d, want 280", stats.HP)
	}
}

func TestCalcCP(t *testing.T) {
	svc := NewCharacterService(nil)
	stats := model.FinalStats{ATK: 100, DEF: 50, HP: 1000, CritRate: 0.05, CritDmg: 1.5, AtkSpeed: 1.0}

	cp := svc.CalcCP(stats)
	// baseDPS = 100 * 1.0 = 100
	// critBonus = 0.05 * 0.5 = 0.025
	// CP = round(100 * 1.025 * 10) / 10 = 102.5
	expected := math.Round(100.0*1.025*10) / 10
	if cp != expected {
		t.Errorf("CP = %f, want %f", cp, expected)
	}
}

func TestCalcCPWithHighCrit(t *testing.T) {
	svc := NewCharacterService(nil)
	stats := model.FinalStats{ATK: 200, DEF: 100, HP: 2000, CritRate: 0.3, CritDmg: 2.0, AtkSpeed: 1.5}

	cp := svc.CalcCP(stats)
	// baseDPS = 200 * 1.5 = 300
	// critBonus = 0.3 * 1.0 = 0.3
	// CP = round(300 * 1.3 * 10) / 10 = 390.0
	expected := math.Round(300.0*1.3*10) / 10
	if cp != expected {
		t.Errorf("CP = %f, want %f", cp, expected)
	}
}

func TestExpToNextLevel(t *testing.T) {
	svc := NewCharacterService(nil)

	tests := []struct {
		level    int
		expected int64
	}{
		{1, 100},  // 100 * 1.15^0
		{2, 115},  // 100 * 1.15^1
		{3, 132},  // 100 * 1.15^2 ≈ 132.25 → round to 132
		{10, 352}, // 100 * 1.15^9 ≈ 351.79 → round to 352
	}

	for _, tt := range tests {
		got := svc.ExpToNextLevel(tt.level)
		// Allow ±1 due to floating point rounding
		if got < tt.expected-1 || got > tt.expected+1 {
			t.Errorf("ExpToNextLevel(%d) = %d, want ~%d", tt.level, got, tt.expected)
		}
	}
}

func TestToResponse(t *testing.T) {
	svc := NewCharacterService(nil)
	c := &model.Character{
		ID:           1,
		AccountID:    100,
		Class:        "warrior",
		Nickname:     "TestHero",
		Level:        5,
		Exp:          50,
		Gold:         200,
		SkillTickets: 10,
	}

	resp := svc.ToResponse(c)

	if resp.ID != 1 {
		t.Errorf("ID = %d, want 1", resp.ID)
	}
	if resp.Nickname != "TestHero" {
		t.Errorf("Nickname = %s, want TestHero", resp.Nickname)
	}
	if resp.Level != 5 {
		t.Errorf("Level = %d, want 5", resp.Level)
	}
	if resp.CP <= 0 {
		t.Errorf("CP = %f, want > 0", resp.CP)
	}
	if resp.ExpToNext <= 0 {
		t.Errorf("ExpToNext = %d, want > 0", resp.ExpToNext)
	}
	if len(resp.Class) == 0 {
		t.Error("Class should not be empty")
	}
}
