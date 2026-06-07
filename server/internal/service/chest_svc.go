package service

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"log/slog"
	"math"
	"math/big"

	"github.com/adventure-game/server/internal/model"
	"github.com/adventure-game/server/internal/repository"
)

type ChestService struct {
	charRepo    *repository.CharacterRepo
	equipRepo   *repository.EquipmentRepo
	equipSvc    *EquipmentService
	currencySvc *CurrencyService
}

func NewChestService(charRepo *repository.CharacterRepo, equipRepo *repository.EquipmentRepo, equipSvc *EquipmentService, currencySvc *CurrencyService) *ChestService {
	return &ChestService{charRepo: charRepo, equipRepo: equipRepo, equipSvc: equipSvc, currencySvc: currencySvc}
}

func (s *ChestService) zoneMaxQuality(zoneLevel int) int {
	switch {
	case zoneLevel <= 4:
		return 2
	case zoneLevel <= 8:
		return 3
	case zoneLevel <= 12:
		return 4
	case zoneLevel <= 16:
		return 5
	case zoneLevel <= 20:
		return 6
	default:
		return 7
	}
}

func (s *ChestService) zoneUpgradeCost(level int) int64 {
	return int64(math.Round(1000 * math.Pow(1.2, float64(level-1))))
}

// GetChestInfo returns chest count, zone level, and upgrade cost.
func (s *ChestService) GetChestInfo(ctx context.Context, charID int64) (map[string]interface{}, error) {
	char, err := s.charRepo.FindByID(ctx, charID)
	if err != nil || char == nil {
		return nil, fmt.Errorf("character not found")
	}
	cost := int64(0)
	if char.ZoneLevel < 28 {
		cost = s.zoneUpgradeCost(char.ZoneLevel)
	}
	maxQ := s.zoneMaxQuality(char.ZoneLevel)
	qualities := make([]int, 0, maxQ)
	for q := 1; q <= maxQ; q++ {
		qualities = append(qualities, q)
	}
	return map[string]interface{}{
		"chest_count":      char.ChestCount,
		"zone_level":       char.ZoneLevel,
		"upgrade_cost":     cost,
		"active_qualities": qualities,
	}, nil
}

// OpenChest opens count chests and generates equipment.
func (s *ChestService) OpenChest(ctx context.Context, charID int64, count int) ([]model.Equipment, int, error) {
	if count < 1 || count > 100 {
		return nil, 0, fmt.Errorf("invalid count")
	}

	tx, err := s.equipRepo.DB().BeginTx(ctx, nil)
	if err != nil {
		return nil, 0, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback()

	char, err := s.charRepo.FindByIDForUpdate(ctx, tx, charID)
	if err != nil || char == nil {
		return nil, 0, fmt.Errorf("character not found")
	}
	if char.ChestCount < count {
		return nil, 0, fmt.Errorf("insufficient chests")
	}

	maxQ := s.zoneMaxQuality(char.ZoneLevel)

	results := make([]model.Equipment, 0, count)
	for i := 0; i < count; i++ {
		quality := s.rollChestQuality(maxQ)
		idx, _ := rand.Int(rand.Reader, big.NewInt(int64(len(model.EquipmentSlots))))
		slot := model.EquipmentSlots[idx.Int64()]

		equip, err := s.equipSvc.GenerateEquipment(slot, quality)
		if err != nil {
			return nil, 0, fmt.Errorf("generate: %w", err)
		}

		// Add to inventory
		eqJSON, _ := json.Marshal(equip)
		if err := s.equipRepo.AddEquipmentInTx(ctx, tx, charID, string(eqJSON)); err != nil {
			return nil, 0, fmt.Errorf("add equipment: %w", err)
		}
		results = append(results, equip)
	}

	// Decrement chest count
	char.ChestCount -= count
	if err := s.charRepo.UpdateChestFieldsInTx(ctx, tx, charID, char.ChestCount, char.ZoneLevel, char.Gold); err != nil {
		return nil, 0, fmt.Errorf("update chest count: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, 0, fmt.Errorf("commit: %w", err)
	}

	return results, char.ChestCount, nil
}

// UpgradeZone levels up the chest zone.
func (s *ChestService) UpgradeZone(ctx context.Context, charID int64) (int, int64, error) {
	tx, err := s.equipRepo.DB().BeginTx(ctx, nil)
	if err != nil {
		return 0, 0, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback()

	char, err := s.charRepo.FindByIDForUpdate(ctx, tx, charID)
	if err != nil || char == nil {
		return 0, 0, fmt.Errorf("character not found")
	}
	if char.ZoneLevel >= 28 {
		return char.ZoneLevel, char.Gold, fmt.Errorf("zone already max level")
	}

	cost := s.zoneUpgradeCost(char.ZoneLevel)
	if char.Gold < cost {
		return char.ZoneLevel, char.Gold, fmt.Errorf("insufficient gold")
	}

	char.Gold -= cost
	char.ZoneLevel++

	if err := s.charRepo.UpdateChestFieldsInTx(ctx, tx, charID, char.ChestCount, char.ZoneLevel, char.Gold); err != nil {
		return 0, 0, fmt.Errorf("update zone: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return 0, 0, fmt.Errorf("commit: %w", err)
	}

	// Write currency log
	if err := s.charRepo.InsertCurrencyLog(ctx, charID, "gold", -cost, "chest_zone_upgrade"); err != nil {
		slog.Error("insert currency log failed", "character_id", charID, "currency", "gold", "amount", -cost, "error", err)
	}

	return char.ZoneLevel, char.Gold, nil
}

func (s *ChestService) rollChestQuality(maxQ int) int {
	// Weighted distribution favoring lower qualities
	weights := map[int]float64{
		1: 0.40, 2: 0.25, 3: 0.15, 4: 0.10, 5: 0.05, 6: 0.03, 7: 0.02,
	}
	available := make([]int, 0)
	for q := 1; q <= maxQ; q++ {
		available = append(available, q)
	}

	total := 0.0
	for _, q := range available {
		total += weights[q]
	}
	r, _ := rand.Int(rand.Reader, big.NewInt(10000))
	roll := float64(r.Int64()) / 10000.0 * total

	cumulative := 0.0
	for _, q := range available {
		cumulative += weights[q]
		if roll < cumulative {
			return q
		}
	}
	return available[len(available)-1]
}
