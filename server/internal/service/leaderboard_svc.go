package service

import (
	"context"
	"fmt"
	"strconv"

	"github.com/redis/go-redis/v9"

	"github.com/adventure-game/server/internal/model"
	"github.com/adventure-game/server/internal/repository"
)

type LeaderboardService struct {
	rdb      *redis.Client
	charRepo *repository.CharacterRepo
}

func NewLeaderboardService(rdb *redis.Client, charRepo *repository.CharacterRepo) *LeaderboardService {
	return &LeaderboardService{rdb: rdb, charRepo: charRepo}
}

func (s *LeaderboardService) leaderboardKey(chapter int) string {
	if chapter > 0 {
		return fmt.Sprintf("leaderboard:chapter:%d", chapter)
	}
	return "leaderboard:global"
}

// RankingEntry represents a leaderboard ranking row.
type RankingEntry struct {
	Rank        int    `json:"rank"`
	CharacterID int64  `json:"character_id"`
	Nickname    string `json:"nickname"`
	Level       int    `json:"level"`
	Chapter     int    `json:"chapter"`
	StageLevel  int    `json:"stage_level"`
	CP          int64  `json:"cp"`
}

// UpdateScore updates a player's score on the leaderboard.
// Score = chapter * 10000 + level
func (s *LeaderboardService) UpdateScore(ctx context.Context, charID int64, chapter, level int) error {
	score := float64(chapter*10000 + level)
	if err := s.rdb.ZAdd(ctx, s.leaderboardKey(0), redis.Z{
		Score:  score,
		Member: strconv.FormatInt(charID, 10),
	}).Err(); err != nil {
		return err
	}

	// Store metadata in Redis hash for fast retrieval
	metaKey := fmt.Sprintf("leaderboard:meta:%d", charID)
	char, err := s.charRepo.FindByID(ctx, charID)
	if err == nil && char != nil {
		base := model.ClassBaseStats[char.Class]
		growth := model.ClassGrowth[char.Class]
		lv := char.Level - 1
		stats := model.FinalStats{
			ATK:      base.ATK + growth.ATK*lv,
			DEF:      base.DEF + growth.DEF*lv,
			HP:       base.HP + growth.HP*lv,
			CritRate: base.CritRate,
			CritDmg:  base.CritDmg,
			AtkSpeed: base.AtkSpeed,
		}
		cp := model.CalcCP(stats, char.Level)
		s.rdb.HSet(ctx, metaKey, map[string]interface{}{
			"nickname":    char.Nickname,
			"level":       char.Level,
			"cp":          cp,
			"chapter":     char.StageChapter,
			"stage_level": char.StageLevel,
		})
	}
	return nil
}

// GetTopN returns the top N players with pagination, populated from character data.
func (s *LeaderboardService) GetTopN(ctx context.Context, page, size, chapter int) ([]RankingEntry, int64, error) {
	if page < 1 {
		page = 1
	}
	if size < 1 || size > 100 {
		size = 50
	}

	key := s.leaderboardKey(chapter)
	start := int64((page - 1) * size)
	stop := start + int64(size) - 1

	results, err := s.rdb.ZRevRangeWithScores(ctx, key, start, stop).Result()
	if err != nil {
		return nil, 0, fmt.Errorf("zrevrange: %w", err)
	}

	total, err := s.rdb.ZCard(ctx, key).Result()
	if err != nil {
		return nil, 0, fmt.Errorf("zcard: %w", err)
	}

	// Collect character IDs for batch lookup (fallback)
	charIDs := make([]int64, 0, len(results))
	for _, z := range results {
		charID, _ := strconv.ParseInt(z.Member.(string), 10, 64)
		charIDs = append(charIDs, charID)
	}

	// Batch fetch character data (fallback)
	charMap, err := s.charRepo.FindByIDs(ctx, charIDs)
	if err != nil {
		return nil, 0, fmt.Errorf("batch find characters: %w", err)
	}

	entries := make([]RankingEntry, 0, len(results))
	for i, z := range results {
		charID, _ := strconv.ParseInt(z.Member.(string), 10, 64)
		metaKey := fmt.Sprintf("leaderboard:meta:%d", charID)
		meta, err := s.rdb.HGetAll(ctx, metaKey).Result()

		entry := RankingEntry{
			Rank:        int(start) + i + 1,
			CharacterID: charID,
			CP:          int64(z.Score),
		}

		if err == nil && len(meta) > 0 {
			entry.Nickname = meta["nickname"]
			if lv, err := strconv.Atoi(meta["level"]); err == nil {
				entry.Level = lv
			}
			if ch, err := strconv.Atoi(meta["chapter"]); err == nil {
				entry.Chapter = ch
			}
			if sl, err := strconv.Atoi(meta["stage_level"]); err == nil {
				entry.StageLevel = sl
			}
		} else {
			// Fallback to DB
			if c, ok := charMap[charID]; ok {
				entry.Nickname = c.Nickname
				entry.Level = c.Level
				entry.Chapter = c.StageChapter
				entry.StageLevel = c.StageLevel
			}
		}
		entries = append(entries, entry)
	}

	return entries, total, nil
}

// GetRank returns a player's full ranking entry.
func (s *LeaderboardService) GetRank(ctx context.Context, charID int64) (*RankingEntry, error) {
	rank, err := s.rdb.ZRevRank(ctx, s.leaderboardKey(0), strconv.FormatInt(charID, 10)).Result()
	if err == redis.Nil {
		return &RankingEntry{Rank: 0}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("zrevrank: %w", err)
	}

	char, err := s.charRepo.FindByID(ctx, charID)
	if err != nil {
		return nil, fmt.Errorf("find character: %w", err)
	}
	if char == nil {
		return &RankingEntry{Rank: int(rank) + 1, CharacterID: charID}, nil
	}

	// Calculate CP score
	base := model.ClassBaseStats[char.Class]
	growth := model.ClassGrowth[char.Class]
	lv := char.Level - 1
	stats := model.FinalStats{
		ATK:      base.ATK + growth.ATK*lv,
		DEF:      base.DEF + growth.DEF*lv,
		HP:       base.HP + growth.HP*lv,
		CritRate: base.CritRate,
		CritDmg:  base.CritDmg,
		AtkSpeed: base.AtkSpeed,
	}
	cp := int64(model.CalcCP(stats, char.Level))

	return &RankingEntry{
		Rank:        int(rank) + 1,
		CharacterID: charID,
		Nickname:    char.Nickname,
		Level:       char.Level,
		Chapter:     char.StageChapter,
		StageLevel:  char.StageLevel,
		CP:          cp,
	}, nil
}
