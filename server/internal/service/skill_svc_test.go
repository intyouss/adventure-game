package service

import (
	"testing"

)

func TestShopLevelByPulls(t *testing.T) {
	svc := NewSkillService(nil, nil)
	tests := []struct {
		pulls int
		want  int
	}{
		{0, 1},
		{100, 1},
		{300, 2},
		{600, 2},
		{1200, 3},
		{2700, 4},
	}
	for _, tt := range tests {
		got := svc.shopLevelByPulls(tt.pulls)
		if got != tt.want {
			t.Errorf("pulls=%d: level=%d, want %d", tt.pulls, got, tt.want)
		}
	}
}

func TestAvailableQualities(t *testing.T) {
	svc := NewSkillService(nil, nil)
	tests := []struct {
		shopLevel  int
		maxQuality int
	}{
		{1, 2}, {4, 2}, {5, 3}, {8, 3}, {9, 4}, {12, 4},
		{13, 5}, {16, 5}, {17, 6}, {20, 6}, {21, 7},
	}
	for _, tt := range tests {
		got := svc.availableQualities(tt.shopLevel)
		if len(got) == 0 || got[len(got)-1] != tt.maxQuality {
			t.Errorf("shopLevel=%d: max quality=%d, want %d", tt.shopLevel, got[len(got)-1], tt.maxQuality)
		}
	}
}

func TestSkillCoefficientGrowth(t *testing.T) {
	svc := NewSkillService(nil, nil)
	tests := []struct {
		baseCoeff float64
		level     int
		want      float64
	}{
		{1.2, 1, 1.2},
		{1.2, 5, 1.44},
		{1.2, 10, 1.74},
		{2.0, 1, 2.0},
		{2.0, 15, 3.4},
	}
	for _, tt := range tests {
		got := svc.calcSkillCoeff(tt.baseCoeff, tt.level)
		if got < tt.want-0.01 || got > tt.want+0.01 {
			t.Errorf("base=%.1f level=%d: coeff=%.2f, want ~%.2f", tt.baseCoeff, tt.level, got, tt.want)
		}
	}
}
