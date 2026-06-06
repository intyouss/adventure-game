package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/adventure-game/server/internal/service"
	"github.com/adventure-game/server/pkg/errcode"
	"github.com/adventure-game/server/pkg/response"
)

type SkillHandler struct {
	svc *service.SkillService
}

func NewSkillHandler(svc *service.SkillService) *SkillHandler {
	return &SkillHandler{svc: svc}
}

// Gacha handles POST /api/skill/gacha
func (h *SkillHandler) Gacha(c *gin.Context) {
	var req struct {
		Count int `json:"count"`
	}
	if err := c.ShouldBindJSON(&req); err != nil || req.Count < 1 {
		req.Count = 1
	}
	if req.Count > 10 {
		req.Count = 10
	}

	charID, exists := c.Get("character_id")
	var cid int64
	if exists && charID.(int64) != 0 {
		cid = charID.(int64)
	} else {
		accountID, _ := c.Get("account_id")
		cid = accountID.(int64)
	}

	results, err := h.svc.GachaPull(c.Request.Context(), cid, req.Count)
	if err != nil {
		if err.Error() == "insufficient skill tickets" {
			response.Error(c, http.StatusBadRequest, errcode.ErrInsufficientTicket, errcode.Msg(errcode.ErrInsufficientTicket))
			return
		}
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, errcode.Msg(errcode.ErrInternal))
		return
	}

	response.OK(c, gin.H{"skills": results})
}

// SetSkillSlot handles POST /api/skill/slot
func (h *SkillHandler) SetSkillSlot(c *gin.Context) {
	var req struct {
		Slot    int    `json:"slot" binding:"required"`
		SkillID string `json:"skill_id"`
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

	if err := h.svc.SetSkillSlot(c.Request.Context(), cid, req.Slot, req.SkillID); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrSkillSlotOccupied, err.Error())
		return
	}

	response.OK(c, nil)
}
