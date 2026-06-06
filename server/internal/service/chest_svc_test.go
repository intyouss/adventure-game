package service

import (
	"testing"
)

func TestZoneMaxQuality(t *testing.T) {
	svc := NewChestService(nil, nil, nil)
	tests := []struct {
		zoneLevel int
		wantMax   int
	}{
		{1, 2}, {4, 2}, {5, 3}, {8, 3}, {9, 4}, {12, 4},
		{13, 5}, {16, 5}, {17, 6}, {20, 6}, {21, 7}, {28, 7},
	}
	for _, tt := range tests {
		got := svc.zoneMaxQuality(tt.zoneLevel)
		if got != tt.wantMax {
			t.Errorf("zoneLevel=%d: max=%d, want %d", tt.zoneLevel, got, tt.wantMax)
		}
	}
}

func TestZoneUpgradeCost(t *testing.T) {
	svc := NewChestService(nil, nil, nil)
	tests := []struct {
		level int
		want  int64
	}{
		{1, 1000},
		{2, 1200},
		{3, 1440},
		{5, 2073},
	}
	for _, tt := range tests {
		got := svc.zoneUpgradeCost(tt.level)
		if got < tt.want-10 || got > tt.want+10 {
			t.Errorf("level=%d: cost=%d, want ~%d", tt.level, got, tt.want)
		}
	}
}
