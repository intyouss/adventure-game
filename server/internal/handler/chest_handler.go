package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/adventure-game/server/internal/service"
	"github.com/adventure-game/server/pkg/errcode"
	"github.com/adventure-game/server/pkg/response"
)

type ChestHandler struct {
	svc *service.ChestService
}

func NewChestHandler(svc *service.ChestService) *ChestHandler {
	return &ChestHandler{svc: svc}
}

// GetChestInfo handles GET /api/chest/info
func (h *ChestHandler) GetChestInfo(c *gin.Context) {
	charID := c.GetInt64("character_id")

	info, err := h.svc.GetChestInfo(c.Request.Context(), charID)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, err.Error())
		return
	}

	response.OK(c, info)
}

// OpenChest handles POST /api/chest/open
// Accepts {"count": N}. Returns {"results": [...], "chests_remaining": N}
func (h *ChestHandler) OpenChest(c *gin.Context) {
	var req struct {
		Count int `json:"count"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || req.Count < 1 {
		req.Count = 1
	}

	charID := c.GetInt64("character_id")

	results, remaining, err := h.svc.OpenChest(c.Request.Context(), charID, req.Count)
	if err != nil {
		if err.Error() == "insufficient chests" {
			response.Error(c, http.StatusBadRequest, errcode.ErrInsufficientChests, errcode.Msg(errcode.ErrInsufficientChests))
			return
		}
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, errcode.Msg(errcode.ErrInternal))
		return
	}

	response.OK(c, gin.H{
		"results":          results,
		"chests_remaining": remaining,
	})
}

// UpgradeZone handles POST /api/chest/upgrade_zone
// Returns {"new_zone_level": N, "gold_remaining": N}
func (h *ChestHandler) UpgradeZone(c *gin.Context) {
	charID := c.GetInt64("character_id")

	newLevel, goldRemaining, err := h.svc.UpgradeZone(c.Request.Context(), charID)
	if err != nil {
		if err.Error() == "insufficient gold" {
			response.Error(c, http.StatusBadRequest, errcode.ErrInsufficientGold, errcode.Msg(errcode.ErrInsufficientGold))
			return
		}
		if err.Error() == "zone already max level" {
			response.Error(c, http.StatusBadRequest, errcode.ErrZoneMaxLevel, errcode.Msg(errcode.ErrZoneMaxLevel))
			return
		}
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, errcode.Msg(errcode.ErrInternal))
		return
	}

	response.OK(c, gin.H{
		"new_zone_level": newLevel,
		"gold_remaining": goldRemaining,
	})
}
