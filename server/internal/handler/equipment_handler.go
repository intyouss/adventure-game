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

// GetEquipment handles GET /api/equipment
func (h *EquipmentHandler) GetEquipment(c *gin.Context) {
	charID, exists := c.Get("character_id")
	var cid int64
	if exists && charID.(int64) != 0 {
		cid = charID.(int64)
	} else {
		accountID, _ := c.Get("account_id")
		cid = accountID.(int64)
	}

	inventory, equipped, err := h.svc.GetInventory(c.Request.Context(), cid)
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

	charID, exists := c.Get("character_id")
	var cid int64
	if exists && charID.(int64) != 0 {
		cid = charID.(int64)
	} else {
		accountID, _ := c.Get("account_id")
		cid = accountID.(int64)
	}

	exp, gold, err := h.svc.Decompose(c.Request.Context(), cid, req.EquipID)
	if err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrItemNotFound, err.Error())
		return
	}

	response.OK(c, gin.H{"exp_gained": exp, "gold_gained": gold})
}
