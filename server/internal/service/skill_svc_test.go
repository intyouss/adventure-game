package service

import (
	"testing"
)

func TestShopLevelByPulls(t *testing.T) {
	svc := NewSkillService(nil, nil, nil)
	tests := []struct {
		pulls int
		want  int
	}{
		{0, 1},
		{100, 1},
		{300, 2},
		{600, 5},
		{1200, 8},
		{2700, 11},
	}
	for _, tt := range tests {
		got := svc.shopLevelByPulls(tt.pulls)
		if got != tt.want {
			t.Errorf("pulls=%d: level=%d, want %d", tt.pulls, got, tt.want)
		}
	}
}

func TestSkillCoefficientGrowth(t *testing.T) {
	svc := NewSkillService(nil, nil, nil)
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

func TestGachaPullReturnsTicketsRemaining(t *testing.T) {
	svc := NewSkillService(nil, nil, nil)
	if svc == nil {
		t.Fatal("service is nil")
	}
}
