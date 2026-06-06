package service

import (
	"context"
	"fmt"
	"math"

	"github.com/adventure-game/server/internal/model"
	"github.com/adventure-game/server/internal/repository"
)

type CharacterService struct {
	repo *repository.CharacterRepo
}

func NewCharacterService(repo *repository.CharacterRepo) *CharacterService {
	return &CharacterService{repo: repo}
}

// CreateCharacter creates a new character for an account after registration.
func (s *CharacterService) CreateCharacter(ctx context.Context, accountID int64, nickname string) (*model.Character, error) {
	c := &model.Character{
		AccountID: accountID,
		Class:     "warrior",
		Nickname:  nickname,
		Level:     1,
		Exp:       0,
		Gold:      0,
	}
	if err := s.repo.Create(ctx, c); err != nil {
		return nil, fmt.Errorf("create character: %w", err)
	}
	return c, nil
}

// GetByAccountID returns the character for an account.
func (s *CharacterService) GetByAccountID(ctx context.Context, accountID int64) (*model.Character, error) {
	return s.repo.FindByAccountID(ctx, accountID)
}

// CalcStats computes final stats from a character's level and class.
func (s *CharacterService) CalcStats(c *model.Character) model.FinalStats {
	base := model.ClassBaseStats[c.Class]
	growth := model.ClassGrowth[c.Class]
	levels := float64(c.Level - 1)

	return model.FinalStats{
		ATK:      base.ATK + int(math.Round(float64(growth.ATK) * levels)),
		DEF:      base.DEF + int(math.Round(float64(growth.DEF) * levels)),
		HP:       base.HP + int(math.Round(float64(growth.HP) * levels)),
		CritRate: base.CritRate,
		CritDmg:  base.CritDmg,
		AtkSpeed: base.AtkSpeed,
	}
}

// CalcCP computes Combat Power (CP).
// Formula: (ATK * 2 + DEF * 1.5 + HP * 0.5) * (1 + level * 0.1)
func (s *CharacterService) CalcCP(stats model.FinalStats, level int) float64 {
	return model.CalcCP(stats, level)
}

// ExpToNextLevel returns experience needed to reach the next level.
func (s *CharacterService) ExpToNextLevel(level int) int64 {
	return model.ExpToNextLevel(level)
}

// AddExp adds experience and handles level-ups.
func (s *CharacterService) AddExp(ctx context.Context, charID int64, amount int64) (*model.Character, error) {
	c, err := s.repo.FindByID(ctx, charID)
	if err != nil {
		return nil, fmt.Errorf("find character: %w", err)
	}
	if c == nil {
		return nil, fmt.Errorf("character not found")
	}

	c.Exp += amount

	// Check for level-ups (max level = 150)
	for c.Level < model.MaxLevel {
		needed := model.ExpToNextLevel(c.Level)
		if c.Exp < needed {
			break
		}
		c.Exp -= needed
		c.Level++
	}

	if err := s.repo.UpdateStats(ctx, c); err != nil {
		return nil, fmt.Errorf("update stats: %w", err)
	}
	return c, nil
}

// CharacterResponse is the DTO returned to clients.
type CharacterResponse struct {
	ID           int64            `json:"id"`
	AccountID    int64            `json:"account_id"`
	Class        string           `json:"class"`
	Nickname     string           `json:"nickname"`
	Level        int              `json:"level"`
	Exp          int64            `json:"exp"`
	ExpToNext    int64            `json:"exp_to_next"`
	Gold         int64            `json:"gold"`
	SkillTickets int64            `json:"skill_tickets"`
	Stats        model.FinalStats `json:"stats"`
	CP           float64          `json:"cp"`
}

func (s *CharacterService) ToResponse(c *model.Character) CharacterResponse {
	stats := s.CalcStats(c)
	return CharacterResponse{
		ID:           c.ID,
		AccountID:    c.AccountID,
		Class:        c.Class,
		Nickname:     c.Nickname,
		Level:        c.Level,
		Exp:          c.Exp,
		ExpToNext:    model.ExpToNextLevel(c.Level),
		Gold:         c.Gold,
		SkillTickets: c.SkillTickets,
		Stats:        stats,
		CP:           model.CalcCP(stats, c.Level),
	}
}
