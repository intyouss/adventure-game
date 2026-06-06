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

func (s *LeaderboardService) leaderboardKey(chapter int) string {
	return fmt.Sprintf("leaderboard:chapter:%d", chapter)
}

// UpdateScore updates a player's progress score on the leaderboard.
func (s *LeaderboardService) UpdateScore(ctx context.Context, charID int64, chapter, level int) error {
	score := float64(chapter*1000 + level)
	return s.rdb.ZAdd(ctx, s.leaderboardKey(chapter), redis.Z{
		Score:  score,
		Member: strconv.FormatInt(charID, 10),
	}).Err()
}

// GetTopN returns the top N players for a chapter.
func (s *LeaderboardService) GetTopN(ctx context.Context, chapter int, n int64) ([]redis.Z, error) {
	return s.rdb.ZRevRangeWithScores(ctx, s.leaderboardKey(chapter), 0, n-1).Result()
}

// GetRank returns a player's rank (1-based) in a chapter.
func (s *LeaderboardService) GetRank(ctx context.Context, charID int64, chapter int) (int64, error) {
	rank, err := s.rdb.ZRevRank(ctx, s.leaderboardKey(chapter), strconv.FormatInt(charID, 10)).Result()
	if err == redis.Nil {
		return 0, nil
	}
	return rank + 1, err
}
