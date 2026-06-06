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

type SkillService struct {
	repo        *repository.SkillRepo
	charRepo    *repository.CharacterRepo
	currencySvc *CurrencyService
}

func NewSkillService(repo *repository.SkillRepo, charRepo *repository.CharacterRepo, currencySvc *CurrencyService) *SkillService {
	return &SkillService{repo: repo, charRepo: charRepo, currencySvc: currencySvc}
}

// shopLevelByPulls computes shop level from total pulls.
// Level N requires 300 * 1.25^(N-1) cumulative pulls.
func (s *SkillService) shopLevelByPulls(totalPulls int) int {
	if totalPulls <= 0 {
		return 1
	}
	for lv := 1; lv <= model.MaxShopLevel; lv++ {
		required := int(math.Round(300 * math.Pow(1.25, float64(lv-1))))
		if totalPulls < required {
			return lv
		}
	}
	return model.MaxShopLevel
}

// rollQuality picks a random quality using weighted probabilities for the shop level.
func (s *SkillService) rollQuality(shopLevel int) int {
	weights := model.GachaWeights(shopLevel)
	total := 0.0
	for _, w := range weights {
		total += w
	}
	r, _ := rand.Int(rand.Reader, big.NewInt(10000))
	roll := float64(r.Int64()) / 10000.0 * total

	cumulative := 0.0
	// Iterate in quality order 1..5
	for q := 1; q <= model.MaxSkillQuality; q++ {
		if w, ok := weights[q]; ok {
			cumulative += w
			if roll < cumulative {
				return q
			}
		}
	}
	// Fallback
	return 1
}

// calcSkillCoeff calculates skill coefficient at a given level (5% growth per level).
func (s *SkillService) calcSkillCoeff(baseCoeff float64, level int) float64 {
	if level <= 1 || baseCoeff == 0 {
		return math.Round(baseCoeff*100) / 100
	}
	return math.Round(baseCoeff*(1+0.05*float64(level-1))*100) / 100
}

// GachaPull performs one or more skill pulls.
func (s *SkillService) GachaPull(ctx context.Context, charID int64, count int) ([]model.Skill, int64, error) {
	if count < 1 || count > 10 {
		return nil, 0, fmt.Errorf("invalid count: %d", count)
	}

	tickets, totalPulls, _, skillsJSON, err := s.repo.GetSkillsData(ctx, charID)
	if err != nil {
		return nil, 0, fmt.Errorf("get skill data: %w", err)
	}
	if tickets < int64(count) {
		return nil, 0, fmt.Errorf("insufficient skill tickets")
	}

	newTickets := tickets - int64(count)

	shopLevel := s.shopLevelByPulls(totalPulls)

	// Parse existing skills
	var skills map[string]model.Skill
	if err := json.Unmarshal([]byte(skillsJSON), &skills); err != nil || skills == nil {
		skills = make(map[string]model.Skill)
	}

	var results []model.Skill
	for i := 0; i < count; i++ {
		quality := s.rollQuality(shopLevel)
		// Find skills matching quality
		var candidates []model.SkillConfig
		for _, sc := range model.SkillPool {
			if sc.Quality == quality {
				candidates = append(candidates, sc)
			}
		}
		if len(candidates) == 0 {
			// Fallback: select from all
			candidates = model.SkillPool
		}
		idx, _ := rand.Int(rand.Reader, big.NewInt(int64(len(candidates))))
		cfg := candidates[idx.Int64()]

		// Merge into existing skills
		if existing, ok := skills[cfg.ID]; ok {
			existing.Cards++
			skills[cfg.ID] = existing
		} else {
			skills[cfg.ID] = model.Skill{
				ID:      cfg.ID,
				Name:    cfg.Name,
				Quality: cfg.Quality,
				Level:   1,
				Cards:   1,
				Coeff:   cfg.BaseCoeff,
			}
		}
		results = append(results, skills[cfg.ID])
	}

	totalPulls += count
	newSkillsJSON, _ := json.Marshal(skills)

	if err := s.repo.UpdateSkills(ctx, charID, newTickets, totalPulls, string(newSkillsJSON)); err != nil {
		return nil, 0, fmt.Errorf("update after pull: %w", err)
	}

	// Write currency log for tickets spent
	_ = s.charRepo.InsertCurrencyLog(ctx, charID, "skill_ticket", -int64(count), "gacha_pull")

	return results, newTickets, nil
}

// SetSkillSlot assigns a skill to a slot (1-4).
func (s *SkillService) SetSkillSlot(ctx context.Context, charID int64, slot int, skillID string) error {
	if slot < 0 || slot > 3 {
		return fmt.Errorf("invalid slot: %d", slot)
	}

	_, _, slotsJSON, _, err := s.repo.GetSkillsData(ctx, charID)
	if err != nil {
		return fmt.Errorf("get skill data: %w", err)
	}

	// Slots stored as JSON array [id1, id2, id3, id4] with null for empty
	var slots []*string
	if err := json.Unmarshal([]byte(slotsJSON), &slots); err != nil || slots == nil {
		slots = make([]*string, 4)
	}
	// Ensure length 4
	for len(slots) < 4 {
		slots = append(slots, nil)
	}

	if skillID == "" {
		slots[slot] = nil
	} else {
		sid := skillID
		slots[slot] = &sid
	}

	newJSON, _ := json.Marshal(slots)
	return s.repo.UpdateSkillSlots(ctx, charID, string(newJSON))
}

// ListSkills returns the player's owned skills.
func (s *SkillService) ListSkills(ctx context.Context, charID int64) ([]model.Skill, error) {
	_, _, _, skillsJSON, err := s.repo.GetSkillsData(ctx, charID)
	if err != nil {
		return nil, fmt.Errorf("get skills data: %w", err)
	}

	var skills map[string]model.Skill
	if err := json.Unmarshal([]byte(skillsJSON), &skills); err != nil {
		return nil, fmt.Errorf("parse skills: %w", err)
	}

	result := make([]model.Skill, 0, len(skills))
	for _, sk := range skills {
		result = append(result, sk)
	}
	return result, nil
}

// GetEquippedSkills returns the equipped skill slots as an array [id1, id2, id3, id4].
func (s *SkillService) GetEquippedSkills(ctx context.Context, charID int64) ([]*string, error) {
	_, _, slotsJSON, _, err := s.repo.GetSkillsData(ctx, charID)
	if err != nil {
		return nil, fmt.Errorf("get skill data: %w", err)
	}
	var slots []*string
	if err := json.Unmarshal([]byte(slotsJSON), &slots); err != nil || slots == nil {
		slots = make([]*string, 4)
	}
	for len(slots) < 4 {
		slots = append(slots, nil)
	}
	return slots, nil
}

// UpgradeSkill upgrades a skill using duplicate cards.
func (s *SkillService) UpgradeSkill(ctx context.Context, charID int64, skillID string) (*model.Skill, error) {
	_, _, _, skillsJSON, err := s.repo.GetSkillsData(ctx, charID)
	if err != nil {
		return nil, fmt.Errorf("get skills data: %w", err)
	}

	var skills map[string]model.Skill
	if err := json.Unmarshal([]byte(skillsJSON), &skills); err != nil || skills == nil {
		return nil, fmt.Errorf("skill not found")
	}

	sk, ok := skills[skillID]
	if !ok {
		return nil, fmt.Errorf("skill not found")
	}

	// Max level check
	if sk.Level >= 30 {
		return nil, fmt.Errorf("skill already max level")
	}

	// Calculate cards needed: ceil(level * 1.15), max 50
	cardsNeeded := int(math.Ceil(float64(sk.Level) * 1.15))
	if cardsNeeded > 50 {
		cardsNeeded = 50
	}

	if sk.Cards < cardsNeeded {
		return nil, fmt.Errorf("insufficient cards for upgrade: need %d, have %d", cardsNeeded, sk.Cards)
	}

	// Find skill config for base coeff
	var baseCoeff float64
	for _, sc := range model.SkillPool {
		if sc.ID == skillID {
			baseCoeff = sc.BaseCoeff
			break
		}
	}

	sk.Cards -= cardsNeeded
	sk.Level++
	sk.Coeff = s.calcSkillCoeff(baseCoeff, sk.Level)
	skills[skillID] = sk

	newSkillsJSON, _ := json.Marshal(skills)
	if err := s.repo.UpdateSkillItem(ctx, charID, string(newSkillsJSON)); err != nil {
		return nil, fmt.Errorf("update skill: %w", err)
	}

	return &sk, nil
}

// ShopInfo returns shop level, total pulls, pulls to next level, and available qualities.
func (s *SkillService) ShopInfo(ctx context.Context, charID int64) (map[string]interface{}, error) {
	_, totalPulls, _, _, err := s.repo.GetSkillsData(ctx, charID)
	if err != nil {
		return nil, fmt.Errorf("get skills data: %w", err)
	}

	shopLevel := s.shopLevelByPulls(totalPulls)
	pullsToNext := 0
	if shopLevel < model.MaxShopLevel {
		required := int(math.Round(300 * math.Pow(1.25, float64(shopLevel))))
		if totalPulls < required {
			pullsToNext = required - totalPulls
		}
	}

	return map[string]interface{}{
		"shop_level":    shopLevel,
		"total_pulls":   totalPulls,
		"pulls_to_next": pullsToNext,
	}, nil
}
