package service

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"log/slog"
	"math/big"

	"github.com/adventure-game/server/internal/model"
	"github.com/adventure-game/server/internal/repository"
)

type EquipmentService struct {
	repo        *repository.EquipmentRepo
	currencySvc *CurrencyService
}

func NewEquipmentService(repo *repository.EquipmentRepo, currencySvc *CurrencyService) *EquipmentService {
	return &EquipmentService{repo: repo, currencySvc: currencySvc}
}

// DecomposeRewardTable: exp and gold rewards per quality level.
var decomposeRewardTable = map[int]struct{ Exp, Gold int64 }{
	1: {10, 50},
	2: {25, 125},
	3: {60, 300},
	4: {150, 750},
	5: {375, 1875},
	6: {900, 4500},
	7: {2250, 11250},
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
			bonus.CritRate += e.CritRate
			bonus.AtkSpeed += e.AtkSpeed
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

	// Secondary stats: CritRate 0-10%, AtkSpeed 0-15% based on quality
	critBase := float64(quality) * 0.01
	critRoll, _ := randFloat(critBase, critBase+0.05)
	aspdBase := 0.95 + float64(quality)*0.01
	aspdRoll, _ := randFloat(aspdBase, aspdBase+0.10)

	name := randomEquipName(slot, quality)
	return model.Equipment{
		ID: id, Name: name, Slot: slot, Quality: quality,
		ATK: atk, DEF: def, HP: hp,
		CritRate: critRoll, AtkSpeed: aspdRoll,
	}, nil
}

// Decompose removes equipment by item_uids and rewards gold + exp using currency service.
func (s *EquipmentService) Decompose(ctx context.Context, charID int64, itemUIDs []string) (totalExp int64, totalGold int64, err error) {
	tx, err := s.repo.DB().BeginTx(ctx, nil)
	if err != nil {
		return 0, 0, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback()

	equipJSON, equippedJSON, currentGold, err := s.repo.GetEquipmentsForUpdate(ctx, tx, charID)
	if err != nil {
		return 0, 0, err
	}

	var inventory []model.Equipment
	if err := json.Unmarshal([]byte(equipJSON), &inventory); err != nil {
		return 0, 0, fmt.Errorf("parse inventory: %w", err)
	}

	var equipped map[string]string
	json.Unmarshal([]byte(equippedJSON), &equipped)
	if equipped == nil {
		equipped = make(map[string]string)
	}

	uidSet := make(map[string]bool)
	for _, uid := range itemUIDs {
		uidSet[uid] = true
	}

	var foundQualities []int
	var newInv []model.Equipment
	for _, e := range inventory {
		if uidSet[e.ID] {
			foundQualities = append(foundQualities, e.Quality)
			// Remove from equipped if equipped
			for slot, id := range equipped {
				if id == e.ID {
					delete(equipped, slot)
				}
			}
		} else {
			newInv = append(newInv, e)
		}
	}
	if len(foundQualities) == 0 {
		return 0, 0, fmt.Errorf("equipment not found")
	}

	// Calculate rewards
	for _, q := range foundQualities {
		r, ok := decomposeRewardTable[q]
		if !ok {
			r = decomposeRewardTable[1]
		}
		totalExp += r.Exp
		totalGold += r.Gold
	}

	newGold := currentGold + totalGold
	newInvJSON, _ := json.Marshal(newInv)
	newEqJSON, _ := json.Marshal(equipped)

	if err := s.repo.UpdateEquipmentsInTx(ctx, tx, charID, string(newInvJSON), string(newEqJSON), newGold); err != nil {
		return 0, 0, fmt.Errorf("save: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return 0, 0, fmt.Errorf("commit: %w", err)
	}

	// Write currency log for gold
	if err := s.currencySvc.charRepo.InsertCurrencyLog(ctx, charID, "gold", totalGold, "decompose_equipment"); err != nil {
		slog.Error("insert currency log failed", "character_id", charID, "currency", "gold", "amount", totalGold, "error", err)
	}

	return totalExp, totalGold, nil
}

// GetInventory returns parsed equipment list and equipped map.
func (s *EquipmentService) GetInventory(ctx context.Context, charID int64) ([]model.Equipment, map[string]string, error) {
	equipJSON, equippedJSON, _, err := s.repo.GetEquipments(ctx, charID)
	if err != nil {
		return nil, nil, err
	}
	inventory := []model.Equipment{}
	equipped := make(map[string]string)
	json.Unmarshal([]byte(equipJSON), &inventory)
	json.Unmarshal([]byte(equippedJSON), &equipped)
	return inventory, equipped, nil
}

// Equip equips an item to a slot.
func (s *EquipmentService) Equip(ctx context.Context, charID int64, equipID string, slot string) error {
	tx, err := s.repo.DB().BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback()

	equipJSON, equippedJSON, gold, err := s.repo.GetEquipmentsForUpdate(ctx, tx, charID)
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

	if err := s.repo.UpdateEquipmentsInTx(ctx, tx, charID, equipJSON, string(newEqJSON), gold); err != nil {
		return fmt.Errorf("save: %w", err)
	}
	return tx.Commit()
}

// Unequip removes an item from a slot.
func (s *EquipmentService) Unequip(ctx context.Context, charID int64, slot string) error {
	tx, err := s.repo.DB().BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback()

	equipJSON, equippedJSON, gold, err := s.repo.GetEquipmentsForUpdate(ctx, tx, charID)
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

	if err := s.repo.UpdateEquipmentsInTx(ctx, tx, charID, equipJSON, string(newEqJSON), gold); err != nil {
		return fmt.Errorf("save: %w", err)
	}
	return tx.Commit()
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

func randomEquipName(slot string, quality int) string {
	slotNames, ok := model.EquipmentNames[slot]
	if !ok {
		return slot
	}
	names, ok := slotNames[quality]
	if !ok || len(names) == 0 {
		names = slotNames[1]
	}
	if len(names) == 0 {
		return slot
	}
	n, _ := rand.Int(rand.Reader, big.NewInt(int64(len(names))))
	return names[n.Int64()]
}

func randFloat(min, max float64) (float64, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(10000))
	if err != nil {
		return 0, err
	}
	r := float64(n.Int64()) / 10000.0
	val := min + r*(max-min)
	// Round to 2 decimal places
	return float64(int(val*100)) / 100, nil
}
