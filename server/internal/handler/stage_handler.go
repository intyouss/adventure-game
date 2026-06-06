package handler

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/adventure-game/server/internal/service"
	"github.com/adventure-game/server/pkg/errcode"
	"github.com/adventure-game/server/pkg/response"
)

type StageHandler struct {
	svc *service.StageService
}

func NewStageHandler(svc *service.StageService) *StageHandler {
	return &StageHandler{svc: svc}
}

func (h *StageHandler) GetStageConfig(c *gin.Context) {
	chapter, _ := strconv.Atoi(c.DefaultQuery("chapter", "1"))
	level, _ := strconv.Atoi(c.DefaultQuery("level", "1"))

	charID := c.GetInt64("character_id")
	if charID == 0 {
		charID = c.GetInt64("account_id")
	}

	cfg, err := h.svc.GetStageConfig(c.Request.Context(), charID, chapter, level)
	if err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrStageNotUnlocked, err.Error())
		return
	}
	response.OK(c, cfg)
}

func (h *StageHandler) ClaimRewards(c *gin.Context) {
	var req struct {
		Chapter int `json:"chapter"`
		Level   int `json:"level"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, errcode.Msg(errcode.ErrInvalidBody))
		return
	}

	charID := c.GetInt64("character_id")
	if charID == 0 {
		charID = c.GetInt64("account_id")
	}

	rewards, err := h.svc.ClaimRewards(c.Request.Context(), charID, req.Chapter, req.Level)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, err.Error())
		return
	}
	response.OK(c, rewards)
}
