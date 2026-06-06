package service

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"math"
	"math/big"

	"github.com/adventure-game/server/internal/model"
	"github.com/adventure-game/server/internal/repository"
)

type ChestService struct {
	charRepo  *repository.CharacterRepo
	equipRepo *repository.EquipmentRepo
	equipSvc  *EquipmentService
}

func NewChestService(charRepo *repository.CharacterRepo, equipRepo *repository.EquipmentRepo, equipSvc *EquipmentService) *ChestService {
	return &ChestService{charRepo: charRepo, equipRepo: equipRepo, equipSvc: equipSvc}
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

// OpenChest opens one chest and generates equipment.
func (s *ChestService) OpenChest(ctx context.Context, charID int64) (*model.Equipment, error) {
	char, err := s.charRepo.FindByID(ctx, charID)
	if err != nil || char == nil {
		return nil, fmt.Errorf("character not found")
	}
	if char.ChestCount < 1 {
		return nil, fmt.Errorf("insufficient chests")
	}

	maxQ := s.zoneMaxQuality(char.ZoneLevel)
	quality := s.rollChestQuality(maxQ)

	// Random slot
	idx, _ := rand.Int(rand.Reader, big.NewInt(int64(len(model.EquipmentSlots))))
	slot := model.EquipmentSlots[idx.Int64()]

	equip, err := s.equipSvc.GenerateEquipment(slot, quality)
	if err != nil {
		return nil, fmt.Errorf("generate: %w", err)
	}

	// Add to inventory
	eqJSON, _ := json.Marshal(equip)
	if err := s.equipRepo.AddEquipment(ctx, charID, string(eqJSON)); err != nil {
		return nil, fmt.Errorf("add equipment: %w", err)
	}

	// Decrement chest count
	char.ChestCount--
	if err := s.charRepo.UpdateChestFields(ctx, charID, char.ChestCount, char.ZoneLevel, char.Gold); err != nil {
		return nil, fmt.Errorf("update chest count: %w", err)
	}

	return &equip, nil
}

// UpgradeZone levels up the chest zone.
func (s *ChestService) UpgradeZone(ctx context.Context, charID int64) (int, int64, error) {
	char, err := s.charRepo.FindByID(ctx, charID)
	if err != nil || char == nil {
		return 0, 0, fmt.Errorf("character not found")
	}
	if char.ZoneLevel >= 28 {
		return char.ZoneLevel, 0, fmt.Errorf("zone already max level")
	}

	cost := s.zoneUpgradeCost(char.ZoneLevel)
	if char.Gold < cost {
		return char.ZoneLevel, cost, fmt.Errorf("insufficient gold")
	}

	char.Gold -= cost
	char.ZoneLevel++

	if err := s.charRepo.UpdateChestFields(ctx, charID, char.ChestCount, char.ZoneLevel, char.Gold); err != nil {
		return 0, 0, fmt.Errorf("update zone: %w", err)
	}

	return char.ZoneLevel, cost, nil
}

func (s *ChestService) rollChestQuality(maxQ int) int {
	// Uniform distribution among available qualities
	n, _ := rand.Int(rand.Reader, big.NewInt(int64(maxQ)))
	return int(n.Int64()) + 1
}
