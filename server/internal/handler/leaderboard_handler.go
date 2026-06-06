package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/adventure-game/server/internal/service"
	"github.com/adventure-game/server/pkg/errcode"
	"github.com/adventure-game/server/pkg/response"
)

type LeaderboardHandler struct {
	svc *service.LeaderboardService
}

func NewLeaderboardHandler(svc *service.LeaderboardService) *LeaderboardHandler {
	return &LeaderboardHandler{svc: svc}
}

func (h *LeaderboardHandler) GetTop(c *gin.Context) {
	chapter, _ := strconv.Atoi(c.DefaultQuery("chapter", "1"))
	topN, _ := strconv.ParseInt(c.DefaultQuery("n", "100"), 10, 64)

	results, err := h.svc.GetTopN(c.Request.Context(), chapter, topN)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, err.Error())
		return
	}
	response.OK(c, results)
}

func (h *LeaderboardHandler) GetMyRank(c *gin.Context) {
	chapter, _ := strconv.Atoi(c.DefaultQuery("chapter", "1"))
	charID := c.GetInt64("character_id")
	if charID == 0 {
		charID = c.GetInt64("account_id")
	}

	rank, err := h.svc.GetRank(c.Request.Context(), charID, chapter)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, err.Error())
		return
	}
	response.OK(c, gin.H{"rank": rank})
}
