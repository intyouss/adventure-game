package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/adventure-game/server/internal/service"
	"github.com/adventure-game/server/pkg/errcode"
	"github.com/adventure-game/server/pkg/response"
)

type EquipmentHandler struct {
	svc *service.EquipmentService
}

func NewEquipmentHandler(svc *service.EquipmentService) *EquipmentHandler {
	return &EquipmentHandler{svc: svc}
}

// GetInventory handles GET /api/equipment/inventory
func (h *EquipmentHandler) GetInventory(c *gin.Context) {
	charID := c.GetInt64("character_id")
	if charID == 0 {
		charID = c.GetInt64("account_id")
	}

	inventory, equipped, err := h.svc.GetInventory(c.Request.Context(), charID)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, errcode.Msg(errcode.ErrInternal))
		return
	}

	response.OK(c, gin.H{
		"inventory": inventory,
		"equipped":  equipped,
	})
}

// Decompose handles POST /api/equipment/decompose
func (h *EquipmentHandler) Decompose(c *gin.Context) {
	var req struct {
		EquipID string `json:"equip_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, errcode.Msg(errcode.ErrInvalidBody))
		return
	}

	charID := c.GetInt64("character_id")
	if charID == 0 {
		charID = c.GetInt64("account_id")
	}

	exp, gold, err := h.svc.Decompose(c.Request.Context(), charID, req.EquipID)
	if err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrItemNotFound, err.Error())
		return
	}

	response.OK(c, gin.H{"exp_gained": exp, "gold_gained": gold})
}

// Equip handles POST /api/equipment/equip
func (h *EquipmentHandler) Equip(c *gin.Context) {
	var req struct {
		EquipID string `json:"equip_id" binding:"required"`
		Slot    string `json:"slot" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, errcode.Msg(errcode.ErrInvalidBody))
		return
	}

	charID := c.GetInt64("character_id")
	if charID == 0 {
		charID = c.GetInt64("account_id")
	}

	if err := h.svc.Equip(c.Request.Context(), charID, req.EquipID, req.Slot); err != nil {
		errMsg := err.Error()
		switch {
		case errMsg == "equipment not found in inventory":
			response.Error(c, http.StatusBadRequest, errcode.ErrItemNotFound, errMsg)
		case errMsg[:4] == "slot":
			response.Error(c, http.StatusBadRequest, errcode.ErrSlotMismatch, errMsg)
		default:
			response.Error(c, http.StatusBadRequest, errcode.ErrSlotOccupied, errMsg)
		}
		return
	}

	response.OK(c, nil)
}

// Unequip handles POST /api/equipment/unequip
func (h *EquipmentHandler) Unequip(c *gin.Context) {
	var req struct {
		Slot string `json:"slot" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, errcode.Msg(errcode.ErrInvalidBody))
		return
	}

	charID := c.GetInt64("character_id")
	if charID == 0 {
		charID = c.GetInt64("account_id")
	}

	if err := h.svc.Unequip(c.Request.Context(), charID, req.Slot); err != nil {
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, err.Error())
		return
	}

	response.OK(c, nil)
}
