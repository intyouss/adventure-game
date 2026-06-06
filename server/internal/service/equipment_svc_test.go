package service

import (
	"testing"

	"github.com/adventure-game/server/internal/model"
)

func TestCalcDecomposeReward(t *testing.T) {
	svc := NewEquipmentService(nil, nil)
	_ = svc
	tests := []struct {
		quality  int
		wantExp  int64
		wantGold int64
	}{
		{1, 10, 50},
		{2, 25, 125},
		{3, 60, 300},
		{4, 150, 750},
		{5, 375, 1875},
		{6, 900, 4500},
		{7, 2250, 11250},
	}
	for _, tt := range tests {
		r, ok := decomposeRewardTable[tt.quality]
		if !ok {
			r = decomposeRewardTable[1]
		}
		if r.Exp != tt.wantExp {
			t.Errorf("quality %d exp = %d, want %d", tt.quality, r.Exp, tt.wantExp)
		}
		if r.Gold != tt.wantGold {
			t.Errorf("quality %d gold = %d, want %d", tt.quality, r.Gold, tt.wantGold)
		}
	}
}

func TestCalcEquipStats(t *testing.T) {
	svc := NewEquipmentService(nil, nil)
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
	svc := NewEquipmentService(nil, nil)
	bonus := svc.calcEquipStats("{}", "[]")
	if bonus.ATK != 0 || bonus.DEF != 0 || bonus.HP != 0 {
		t.Error("Empty equipment should give zero bonus")
	}
}

func TestGenerateEquipment(t *testing.T) {
	svc := NewEquipmentService(nil, nil)
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
	svc := NewEquipmentService(nil, nil)
	_, err := svc.GenerateEquipment("weapon", 99)
	if err == nil {
		t.Error("Expected error for invalid quality")
	}
}

func TestCalcDecomposeRewardMultiplier(t *testing.T) {
	_ = NewEquipmentService(nil, nil)
	r2 := decomposeRewardTable[2]
	r3 := decomposeRewardTable[3]
	if r3.Exp <= r2.Exp {
		t.Errorf("Quality 3 exp = %d should be > quality 2 exp = %d", r3.Exp, r2.Exp)
	}
	if r3.Gold <= r2.Gold {
		t.Errorf("Quality 3 gold = %d should be > quality 2 gold = %d", r3.Gold, r2.Gold)
	}
}
