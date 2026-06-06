package service

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"math/big"

	"github.com/adventure-game/server/internal/model"
	"github.com/adventure-game/server/internal/repository"
)

type EquipmentService struct {
	repo *repository.EquipmentRepo
}

func NewEquipmentService(repo *repository.EquipmentRepo) *EquipmentService {
	return &EquipmentService{repo: repo}
}

// calcDecomposeReward calculates exp and gold from decomposing equipment.
// Returns (exp, gold).
func (s *EquipmentService) calcDecomposeReward(quality int) (int64, int64) {
	baseExp := int64(10)
	baseGold := int64(50)
	mult := int64(1)
	for i := 1; i < quality; i++ {
		mult = mult * 5 / 2
	}
	return baseExp * mult, baseGold * mult
}

// calcEquipStats sums stats from equipped items.
func (s *EquipmentService) calcEquipStats(equippedJSON string, equipmentsJSON string) model.FinalStats {
	var equipped map[string]string
	var inventory []model.Equipment
	json.Unmarshal([]byte(equippedJSON), &equipped)
	json.Unmarshal([]byte(equipmentsJSON), &inventory)

	bonus := model.FinalStats{}
	equipMap := make(map[string]model.Equipment)
	for _, e := range inventory {
		equipMap[e.ID] = e
	}
	for _, equipID := range equipped {
		if e, ok := equipMap[equipID]; ok {
			bonus.ATK += e.ATK
			bonus.DEF += e.DEF
			bonus.HP += e.HP
		}
	}
	return bonus
}

// GenerateEquipment creates random equipment for a given slot and quality.
func (s *EquipmentService) GenerateEquipment(slot string, quality int) (model.Equipment, error) {
	ranges, ok := model.QualityStatRanges[quality]
	if !ok {
		return model.Equipment{}, fmt.Errorf("invalid quality: %d", quality)
	}
	atk, _ := randInt(ranges[0][0], ranges[0][1])
	def, _ := randInt(ranges[1][0], ranges[1][1])
	hp, _ := randInt(ranges[2][0], ranges[2][1])
	id, _ := generateEquipID()

	return model.Equipment{
		ID: id, Slot: slot, Quality: quality, ATK: atk, DEF: def, HP: hp,
	}, nil
}

// Decompose removes equipment and rewards gold.
func (s *EquipmentService) Decompose(ctx context.Context, charID int64, equipID string) (exp int64, gold int64, err error) {
	equipJSON, equippedJSON, currentGold, err := s.repo.GetEquipments(ctx, charID)
	if err != nil {
		return 0, 0, err
	}

	var inventory []model.Equipment
	if err := json.Unmarshal([]byte(equipJSON), &inventory); err != nil {
		return 0, 0, fmt.Errorf("parse inventory: %w", err)
	}

	var found *model.Equipment
	var newInv []model.Equipment
	for _, e := range inventory {
		if e.ID == equipID {
			cp := e
			found = &cp
		} else {
			newInv = append(newInv, e)
		}
	}
	if found == nil {
		return 0, 0, fmt.Errorf("equipment not found")
	}

	var equipped map[string]string
	json.Unmarshal([]byte(equippedJSON), &equipped)
	for slot, id := range equipped {
		if id == equipID {
			delete(equipped, slot)
		}
	}

	exp, gold = s.calcDecomposeReward(found.Quality)
	newInvJSON, _ := json.Marshal(newInv)
	newEqJSON, _ := json.Marshal(equipped)

	if err := s.repo.UpdateEquipments(ctx, charID, string(newInvJSON), string(newEqJSON), currentGold+gold); err != nil {
		return 0, 0, fmt.Errorf("save: %w", err)
	}
	return exp, gold, nil
}

// GetInventory returns parsed equipment list and equipped map.
func (s *EquipmentService) GetInventory(ctx context.Context, charID int64) ([]model.Equipment, map[string]string, error) {
	equipJSON, equippedJSON, _, err := s.repo.GetEquipments(ctx, charID)
	if err != nil {
		return nil, nil, err
	}
	var inventory []model.Equipment
	var equipped map[string]string
	json.Unmarshal([]byte(equipJSON), &inventory)
	json.Unmarshal([]byte(equippedJSON), &equipped)
	if equipped == nil {
		equipped = make(map[string]string)
	}
	if inventory == nil {
		inventory = []model.Equipment{}
	}
	return inventory, equipped, nil
}

// Equip equips an item to a slot.
func (s *EquipmentService) Equip(ctx context.Context, charID int64, equipID string, slot string) error {
	equipJSON, equippedJSON, gold, err := s.repo.GetEquipments(ctx, charID)
	if err != nil {
		return fmt.Errorf("get equipments: %w", err)
	}

	var inventory []model.Equipment
	if err := json.Unmarshal([]byte(equipJSON), &inventory); err != nil {
		return fmt.Errorf("parse inventory: %w", err)
	}

	// Find the equipment in inventory
	var target *model.Equipment
	for i, e := range inventory {
		if e.ID == equipID {
			target = &inventory[i]
			break
		}
	}
	if target == nil {
		return fmt.Errorf("equipment not found in inventory")
	}

	// Verify slot matches equipment's slot
	if target.Slot != slot {
		return fmt.Errorf("slot mismatch: equipment is for %s, requested %s", target.Slot, slot)
	}

	// Check slot not already occupied
	var equipped map[string]string
	if err := json.Unmarshal([]byte(equippedJSON), &equipped); err != nil {
		equipped = make(map[string]string)
	}
	if equipped == nil {
		equipped = make(map[string]string)
	}
	if _, occupied := equipped[slot]; occupied {
		return fmt.Errorf("slot %s already occupied", slot)
	}

	// Equip the item
	equipped[slot] = equipID
	newEqJSON, _ := json.Marshal(equipped)

	return s.repo.UpdateEquipments(ctx, charID, equipJSON, string(newEqJSON), gold)
}

// Unequip removes an item from a slot.
func (s *EquipmentService) Unequip(ctx context.Context, charID int64, slot string) error {
	equipJSON, equippedJSON, gold, err := s.repo.GetEquipments(ctx, charID)
	if err != nil {
		return fmt.Errorf("get equipments: %w", err)
	}

	var equipped map[string]string
	if err := json.Unmarshal([]byte(equippedJSON), &equipped); err != nil {
		equipped = make(map[string]string)
	}
	if equipped == nil {
		equipped = make(map[string]string)
	}

	delete(equipped, slot)
	newEqJSON, _ := json.Marshal(equipped)

	return s.repo.UpdateEquipments(ctx, charID, equipJSON, string(newEqJSON), gold)
}

func generateEquipID() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(999999))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("e-%06d", n.Int64()), nil
}

func randInt(min, max int) (int, error) {
	if min >= max {
		return min, nil
	}
	n, err := rand.Int(rand.Reader, big.NewInt(int64(max-min+1)))
	if err != nil {
		return 0, err
	}
	return min + int(n.Int64()), nil
}
