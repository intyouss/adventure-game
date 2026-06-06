package service

import (
	"testing"

	"github.com/adventure-game/server/internal/model"
)

func TestCalcDecomposeReward(t *testing.T) {
	svc := NewEquipmentService(nil)
	tests := []struct {
		quality  int
		wantExp  int64
		wantGold int64
	}{
		{1, 10, 50},
		{2, 20, 100},
		{3, 50, 250},
		{4, 120, 600},
		{5, 300, 1500},
		{6, 750, 3750},
		{7, 1870, 9350},
	}
	for _, tt := range tests {
		exp, gold := svc.calcDecomposeReward(tt.quality)
		if exp != tt.wantExp {
			t.Errorf("quality %d exp = %d, want %d", tt.quality, exp, tt.wantExp)
		}
		if gold != tt.wantGold {
			t.Errorf("quality %d gold = %d, want %d", tt.quality, gold, tt.wantGold)
		}
	}
}

func TestCalcEquipStats(t *testing.T) {
	svc := NewEquipmentService(nil)
	equipped := "{\"weapon\":\"e-001\",\"helmet\":\"e-002\"}"
	inventory := "[{\"id\":\"e-001\",\"slot\":\"weapon\",\"quality\":3,\"atk\":12,\"def\":0,\"hp\":0},{\"id\":\"e-002\",\"slot\":\"helmet\",\"quality\":2,\"atk\":0,\"def\":5,\"hp\":10},{\"id\":\"e-003\",\"slot\":\"armor\",\"quality\":4,\"atk\":0,\"def\":15,\"hp\":50}]"

	bonus := svc.calcEquipStats(equipped, inventory)
	if bonus.ATK != 12 {
		t.Errorf("ATK = %d, want 12", bonus.ATK)
	}
	if bonus.DEF != 5 {
		t.Errorf("DEF = %d, want 5", bonus.DEF)
	}
	if bonus.HP != 10 {
		t.Errorf("HP = %d, want 10", bonus.HP)
	}
}

func TestCalcEquipStatsEmpty(t *testing.T) {
	svc := NewEquipmentService(nil)
	bonus := svc.calcEquipStats("{}", "[]")
	if bonus.ATK != 0 || bonus.DEF != 0 || bonus.HP != 0 {
		t.Error("Empty equipment should give zero bonus")
	}
}

func TestGenerateEquipment(t *testing.T) {
	svc := NewEquipmentService(nil)
	eq, err := svc.GenerateEquipment("weapon", 3)
	if err != nil {
		t.Fatalf("GenerateEquipment failed: %v", err)
	}
	if eq.Slot != "weapon" {
		t.Errorf("Slot = %s, want weapon", eq.Slot)
	}
	if eq.Quality != 3 {
		t.Errorf("Quality = %d, want 3", eq.Quality)
	}
	if eq.ID == "" {
		t.Error("ID should not be empty")
	}
	ranges := model.QualityStatRanges[3]
	if eq.ATK < ranges[0][0] || eq.ATK > ranges[0][1] {
		t.Errorf("ATK = %d, want [%d, %d]", eq.ATK, ranges[0][0], ranges[0][1])
	}
	if eq.DEF < ranges[1][0] || eq.DEF > ranges[1][1] {
		t.Errorf("DEF = %d, want [%d, %d]", eq.DEF, ranges[1][0], ranges[1][1])
	}
	if eq.HP < ranges[2][0] || eq.HP > ranges[2][1] {
		t.Errorf("HP = %d, want [%d, %d]", eq.HP, ranges[2][0], ranges[2][1])
	}
}

func TestGenerateEquipmentInvalidQuality(t *testing.T) {
	svc := NewEquipmentService(nil)
	_, err := svc.GenerateEquipment("weapon", 99)
	if err == nil {
		t.Error("Expected error for invalid quality")
	}
}

func TestCalcDecomposeRewardMultiplier(t *testing.T) {
	svc := NewEquipmentService(nil)
	exp2, gold2 := svc.calcDecomposeReward(2)
	exp3, gold3 := svc.calcDecomposeReward(3)
	if exp3 != exp2*5/2 {
		t.Errorf("Quality 3 exp = %d, want %d (2.5x quality 2)", exp3, exp2*5/2)
	}
	if gold3 != gold2*5/2 {
		t.Errorf("Quality 3 gold = %d, want %d (2.5x quality 2)", gold3, gold2*5/2)
	}
}