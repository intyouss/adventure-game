package service

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	"github.com/adventure-game/server/internal/model"
	"github.com/adventure-game/server/internal/repository"
)

type StageService struct {
	charRepo *repository.CharacterRepo
}

func NewStageService(charRepo *repository.CharacterRepo) *StageService {
	return &StageService{charRepo: charRepo}
}

// parseStageID splits "1-5" into chapter, level.
func parseStageID(stageID string) (int, int, error) {
	parts := strings.SplitN(stageID, "-", 2)
	if len(parts) != 2 {
		return 0, 0, fmt.Errorf("invalid stage_id: %s", stageID)
	}
	chapter, err := strconv.Atoi(parts[0])
	if err != nil {
		return 0, 0, fmt.Errorf("invalid stage_id chapter: %s", parts[0])
	}
	level, err := strconv.Atoi(parts[1])
	if err != nil {
		return 0, 0, fmt.Errorf("invalid stage_id level: %s", parts[1])
	}
	return chapter, level, nil
}

// GetChapterStages returns configs for all 10 levels in a chapter.
func (s *StageService) GetChapterStages(ctx context.Context, chapter int) ([]model.StageConfig, error) {
	stages := make([]model.StageConfig, 0, 10)
	for level := 1; level <= 10; level++ {
		stages = append(stages, model.GenerateStageConfig(chapter, level))
	}
	return stages, nil
}

// GetStageConfig returns the stage config if the player has unlocked it.
func (s *StageService) GetStageConfig(ctx context.Context, charID int64, stageID string) (*model.StageConfig, error) {
	chapter, level, err := parseStageID(stageID)
	if err != nil {
		return nil, err
	}

	char, err := s.charRepo.FindByID(ctx, charID)
	if err != nil || char == nil {
		return nil, fmt.Errorf("character not found")
	}

	// Check unlock: stage must be at or before the next stage after current progress
	requiredChapter, requiredLevel := s.nextStage(char.StageChapter, char.StageLevel)
	if chapter > requiredChapter || (chapter == requiredChapter && level > requiredLevel) {
		return nil, fmt.Errorf("stage not unlocked")
	}

	cfg := model.GenerateStageConfig(chapter, level)
	return &cfg, nil
}

// nextStage returns the chapter/level that would come after the current one.
func (s *StageService) nextStage(chapter, level int) (int, int) {
	if level < 10 {
		return chapter, level + 1
	}
	return chapter + 1, 1
}

// GetProgress returns the current stage progress.
func (s *StageService) GetProgress(ctx context.Context, charID int64) (map[string]interface{}, error) {
	char, err := s.charRepo.FindByID(ctx, charID)
	if err != nil || char == nil {
		return nil, fmt.Errorf("character not found")
	}
	nextCh, nextLv := s.nextStage(char.StageChapter, char.StageLevel)
	return map[string]interface{}{
		"chapter":       char.StageChapter,
		"level":         char.StageLevel,
		"next_stage_id": fmt.Sprintf("%d-%d", nextCh, nextLv),
	}, nil
}

// ClaimRewards claims stage rewards and advances progress.
func (s *StageService) ClaimRewards(ctx context.Context, charID int64, stageID string) (*model.StageRewards, error) {
	chapter, level, err := parseStageID(stageID)
	if err != nil {
		return nil, err
	}

	rewards := model.CalculateRewards(chapter, level)
	char, err := s.charRepo.FindByID(ctx, charID)
	if err != nil || char == nil {
		return nil, fmt.Errorf("character not found")
	}

	char.Gold += rewards.Gold
	char.SkillTickets += rewards.SkillTickets
	char.ChestCount += rewards.Chests

	// Advance progress if this is the next expected stage
	nextCh, nextLv := s.nextStage(char.StageChapter, char.StageLevel)
	if chapter == nextCh && level == nextLv {
		char.StageChapter = chapter
		char.StageLevel = level
	}

	if err := s.charRepo.UpdateStats(ctx, char); err != nil {
		return nil, fmt.Errorf("update rewards: %w", err)
	}

	return &rewards, nil
}
