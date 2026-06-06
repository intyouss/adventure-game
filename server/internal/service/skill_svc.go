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
	repo     *repository.SkillRepo
	charRepo *repository.CharacterRepo
}

func NewSkillService(repo *repository.SkillRepo, charRepo *repository.CharacterRepo) *SkillService {
	return &SkillService{repo: repo, charRepo: charRepo}
}

var qualityProbabilities = map[int]float64{
	1: 0.50, 2: 0.30, 3: 0.12, 4: 0.05, 5: 0.02, 6: 0.008, 7: 0.002,
}

// shopLevelByPulls computes shop level from total pulls.
func (s *SkillService) shopLevelByPulls(totalPulls int) int {
	level := int(math.Sqrt(float64(totalPulls)/300)) + 1
	if level > 28 {
		level = 28
	}
	return level
}

// availableQualities returns the list of quality levels available at a given shop level.
func (s *SkillService) availableQualities(shopLevel int) []int {
	var maxQ int
	switch {
	case shopLevel <= 4:
		maxQ = 2
	case shopLevel <= 8:
		maxQ = 3
	case shopLevel <= 12:
		maxQ = 4
	case shopLevel <= 16:
		maxQ = 5
	case shopLevel <= 20:
		maxQ = 6
	default:
		maxQ = 7
	}
	qualities := make([]int, 0, maxQ)
	for q := 1; q <= maxQ; q++ {
		qualities = append(qualities, q)
	}
	return qualities
}

// rollQuality picks a random quality from the available pool using weighted probabilities.
func (s *SkillService) rollQuality(available []int) int {
	total := 0.0
	for _, q := range available {
		total += qualityProbabilities[q]
	}
	r, _ := rand.Int(rand.Reader, big.NewInt(10000))
	roll := float64(r.Int64()) / 10000.0 * total

	cumulative := 0.0
	for _, q := range available {
		cumulative += qualityProbabilities[q]
		if roll < cumulative {
			return q
		}
	}
	return available[len(available)-1]
}

// calcSkillCoeff calculates skill coefficient at a given level (5% growth per level).
func (s *SkillService) calcSkillCoeff(baseCoeff float64, level int) float64 {
	if level <= 1 || baseCoeff == 0 {
		return math.Round(baseCoeff*100) / 100
	}
	return math.Round(baseCoeff*(1+0.05*float64(level-1))*100) / 100
}

// GachaPull performs one or more skill pulls.
func (s *SkillService) GachaPull(ctx context.Context, charID int64, count int) ([]model.Skill, error) {
	if count < 1 || count > 10 {
		return nil, fmt.Errorf("invalid count: %d", count)
	}

	tickets, totalPulls, _, skillsJSON, err := s.repo.GetSkillsData(ctx, charID)
	if err != nil {
		return nil, fmt.Errorf("get skill data: %w", err)
	}
	if tickets < int64(count) {
		return nil, fmt.Errorf("insufficient skill tickets")
	}

	shopLevel := s.shopLevelByPulls(totalPulls)
	available := s.availableQualities(shopLevel)

	// Parse existing skills
	var skills map[string]model.Skill
	if err := json.Unmarshal([]byte(skillsJSON), &skills); err != nil || skills == nil {
		skills = make(map[string]model.Skill)
	}

	var results []model.Skill
	for i := 0; i < count; i++ {
		quality := s.rollQuality(available)
		var candidates []model.SkillConfig
		for _, sc := range model.SkillPool {
			if sc.Quality == quality {
				candidates = append(candidates, sc)
			}
		}
		if len(candidates) == 0 {
			continue
		}
		idx, _ := rand.Int(rand.Reader, big.NewInt(int64(len(candidates))))
		cfg := candidates[idx.Int64()]

		// Merge into existing skills: if already owned, add a card; otherwise create new
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

	if err := s.repo.UpdateSkills(ctx, charID, tickets-int64(count), totalPulls, string(newSkillsJSON)); err != nil {
		return nil, fmt.Errorf("update after pull: %w", err)
	}

	return results, nil
}

// SetSkillSlot assigns a skill to a slot (1-4).
func (s *SkillService) SetSkillSlot(ctx context.Context, charID int64, slot int, skillID string) error {
	if slot < 1 || slot > 4 {
		return fmt.Errorf("invalid slot: %d", slot)
	}

	_, _, slotsJSON, err := s.repo.GetSkillData(ctx, charID)
	if err != nil {
		return fmt.Errorf("get skill data: %w", err)
	}

	var slots map[string]string
	if err := json.Unmarshal([]byte(slotsJSON), &slots); err != nil || slots == nil {
		slots = map[string]string{"1": "", "2": "", "3": "", "4": ""}
	}
	slotKey := fmt.Sprintf("%d", slot)
	slots[slotKey] = skillID
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

// ShopInfo returns shop level, total pulls, and available qualities.
func (s *SkillService) ShopInfo(ctx context.Context, charID int64) (map[string]interface{}, error) {
	_, totalPulls, _, _, err := s.repo.GetSkillsData(ctx, charID)
	if err != nil {
		return nil, fmt.Errorf("get skills data: %w", err)
	}

	shopLevel := s.shopLevelByPulls(totalPulls)
	available := s.availableQualities(shopLevel)

	return map[string]interface{}{
		"shop_level":        shopLevel,
		"total_pulls":       totalPulls,
		"available_qualities": available,
	}, nil
}
