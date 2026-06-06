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

func (h *ChestHandler) OpenChest(c *gin.Context) {
	charID := c.GetInt64("character_id")
	if charID == 0 {
		charID = c.GetInt64("account_id")
	}

	equip, err := h.svc.OpenChest(c.Request.Context(), charID)
	if err != nil {
		if err.Error() == "insufficient chests" {
			response.Error(c, http.StatusBadRequest, errcode.ErrInsufficientChests, errcode.Msg(errcode.ErrInsufficientChests))
			return
		}
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, errcode.Msg(errcode.ErrInternal))
		return
	}

	response.OK(c, equip)
}

func (h *ChestHandler) UpgradeZone(c *gin.Context) {
	charID := c.GetInt64("character_id")
	if charID == 0 {
		charID = c.GetInt64("account_id")
	}

	newLevel, cost, err := h.svc.UpgradeZone(c.Request.Context(), charID)
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

	response.OK(c, gin.H{"zone_level": newLevel, "cost": cost})
}
