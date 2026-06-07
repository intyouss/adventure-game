package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/adventure-game/server/internal/service"
	"github.com/adventure-game/server/pkg/errcode"
	"github.com/adventure-game/server/pkg/logger"
	"github.com/adventure-game/server/pkg/response"
)

type LeaderboardHandler struct {
	svc *service.LeaderboardService
}

func NewLeaderboardHandler(svc *service.LeaderboardService) *LeaderboardHandler {
	return &LeaderboardHandler{svc: svc}
}

// GetTop handles GET /api/leaderboard?page=1&size=50&chapter=1
func (h *LeaderboardHandler) GetTop(c *gin.Context) {
	pageStr := c.DefaultQuery("page", "1")
	sizeStr := c.DefaultQuery("size", "50")
	chapterStr := c.DefaultQuery("chapter", "0")

	page, _ := strconv.Atoi(pageStr)
	size, _ := strconv.Atoi(sizeStr)
	chapter, _ := strconv.Atoi(chapterStr)

	logger.Info(c, "[GET_TOP]", "page", page, "size", size, "chapter", chapter)
	rankings, total, err := h.svc.GetTopN(c.Request.Context(), page, size, chapter)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, err.Error())
		return
	}

	response.OK(c, gin.H{
		"rankings": rankings,
		"total":    total,
		"page":     page,
		"size":     size,
	})
}

// GetMyRank handles GET /api/leaderboard/my_rank
func (h *LeaderboardHandler) GetMyRank(c *gin.Context) {
	charID := c.GetInt64("character_id")

	logger.Info(c, "[GET_MY_RANK]")
	entry, err := h.svc.GetRank(c.Request.Context(), charID)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, err.Error())
		return
	}
	response.OK(c, entry)
}
