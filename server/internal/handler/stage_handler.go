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

type StageHandler struct {
	svc *service.StageService
}

func NewStageHandler(svc *service.StageService) *StageHandler {
	return &StageHandler{svc: svc}
}

// GetStageConfig handles GET /api/stage/start?stage_id=1-3
func (h *StageHandler) GetStageConfig(c *gin.Context) {
	stageID := c.DefaultQuery("stage_id", "1-1")

	charID := c.GetInt64("character_id")

	logger.Info(c, "[GET_STAGE_CONFIG]", "stage_id", stageID)
	cfg, err := h.svc.GetStageConfig(c.Request.Context(), charID, stageID)
	if err != nil {
		errMsg := err.Error()
		switch errMsg {
		case "stage not found":
			response.Error(c, http.StatusNotFound, errcode.ErrStageNotFound, errcode.Msg(errcode.ErrStageNotFound))
		case "stage not unlocked":
			response.Error(c, http.StatusBadRequest, errcode.ErrStageNotUnlocked, errMsg)
		default:
			response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, errMsg)
		}
		return
	}
	response.OK(c, cfg)
}

// GetProgress handles GET /api/stage/progress
func (h *StageHandler) GetProgress(c *gin.Context) {
	charID := c.GetInt64("character_id")

	logger.Info(c, "[GET_PROGRESS]")
	progress, err := h.svc.GetProgress(c.Request.Context(), charID)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, err.Error())
		return
	}
	response.OK(c, progress)
}

// ClaimRewards handles POST /api/stage/complete
// Accepts {"stage_id": "1-5"}
func (h *StageHandler) ClaimRewards(c *gin.Context) {
	var req struct {
		StageID string `json:"stage_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, errcode.Msg(errcode.ErrInvalidBody))
		return
	}

	charID := c.GetInt64("character_id")

	logger.Info(c, "[CLAIM_REWARDS]", "stage_id", req.StageID)
	rewards, err := h.svc.ClaimRewards(c.Request.Context(), charID, req.StageID)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, err.Error())
		return
	}
	response.OK(c, rewards)
}

// GetChapterStages handles GET /api/stage/config?chapter=1
func (h *StageHandler) GetChapterStages(c *gin.Context) {
	chapterStr := c.DefaultQuery("chapter", "1")
	chapter, err := strconv.Atoi(chapterStr)
	if err != nil || chapter < 1 {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, "invalid chapter")
		return
	}
	logger.Info(c, "[GET_CHAPTER_STAGES]", "chapter", chapter)
	stages, err := h.svc.GetChapterStages(c.Request.Context(), chapter)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, err.Error())
		return
	}
	response.OK(c, stages)
}
