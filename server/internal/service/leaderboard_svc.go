package service

import (
	"context"
	"fmt"
	"strconv"

	"github.com/redis/go-redis/v9"
)

type LeaderboardService struct {
	rdb *redis.Client
}

func NewLeaderboardService(rdb *redis.Client) *LeaderboardService {
	return &LeaderboardService{rdb: rdb}
}

func (s *LeaderboardService) leaderboardKey() string {
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
// Score = chapter * 1000 + stage_level
func (s *LeaderboardService) UpdateScore(ctx context.Context, charID int64, chapter, level int) error {
	score := float64(chapter*1000 + level)
	return s.rdb.ZAdd(ctx, s.leaderboardKey(), redis.Z{
		Score:  score,
		Member: strconv.FormatInt(charID, 10),
	}).Err()
}

// GetTopN returns the top N players with pagination.
func (s *LeaderboardService) GetTopN(ctx context.Context, page, size int) ([]RankingEntry, int64, error) {
	if page < 1 {
		page = 1
	}
	if size < 1 || size > 100 {
		size = 50
	}

	start := int64((page - 1) * size)
	stop := start + int64(size) - 1

	results, err := s.rdb.ZRevRangeWithScores(ctx, s.leaderboardKey(), start, stop).Result()
	if err != nil {
		return nil, 0, fmt.Errorf("zrevrange: %w", err)
	}

	total, err := s.rdb.ZCard(ctx, s.leaderboardKey()).Result()
	if err != nil {
		return nil, 0, fmt.Errorf("zcard: %w", err)
	}

	entries := make([]RankingEntry, 0, len(results))
	for i, z := range results {
		charID, _ := strconv.ParseInt(z.Member.(string), 10, 64)
		entries = append(entries, RankingEntry{
			Rank:        int(start) + i + 1,
			CharacterID: charID,
			Nickname:    "", // populated by handler from character data
			Level:       0,
			Chapter:     0,
			StageLevel:  0,
			CP:          int64(z.Score),
		})
	}

	return entries, total, nil
}

// GetRank returns a player's rank (1-based) globally.
func (s *LeaderboardService) GetRank(ctx context.Context, charID int64) (int64, error) {
	rank, err := s.rdb.ZRevRank(ctx, s.leaderboardKey(), strconv.FormatInt(charID, 10)).Result()
	if err == redis.Nil {
		return 0, nil
	}
	return rank + 1, err
}
