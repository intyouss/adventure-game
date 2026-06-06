package service

import (
	"context"
	"fmt"

	"github.com/adventure-game/server/internal/model"
	"github.com/adventure-game/server/internal/repository"
)

type StageService struct {
	charRepo *repository.CharacterRepo
}

func NewStageService(charRepo *repository.CharacterRepo) *StageService {
	return &StageService{charRepo: charRepo}
}

func (s *StageService) GetStageConfig(ctx context.Context, charID int64, chapter, level int) (*model.StageConfig, error) {
	char, err := s.charRepo.FindByID(ctx, charID)
	if err != nil || char == nil {
		return nil, fmt.Errorf("character not found")
	}

	// Check unlock: player must have cleared previous level
	requiredProgress := (chapter-1)*10 + level - 1
	currentProgress := 0 // TODO: track from stage_progress

	if requiredProgress > currentProgress+1 {
		return nil, fmt.Errorf("stage not unlocked")
	}

	cfg := model.GenerateStageConfig(chapter, level)
	return &cfg, nil
}

func (s *StageService) ClaimRewards(ctx context.Context, charID int64, chapter, level int) (*model.StageRewards, error) {
	rewards := model.CalculateRewards(chapter, level)
	char, err := s.charRepo.FindByID(ctx, charID)
	if err != nil || char == nil {
		return nil, fmt.Errorf("character not found")
	}

	char.Gold += rewards.Gold
	char.SkillTickets += rewards.SkillTickets
	char.ChestCount += rewards.Chests

	if err := s.charRepo.UpdateStats(ctx, char); err != nil {
		return nil, fmt.Errorf("update rewards: %w", err)
	}

	return &rewards, nil
}
