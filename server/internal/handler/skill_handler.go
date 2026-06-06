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

	charID := c.GetInt64("character_id")
	if charID == 0 {
		charID = c.GetInt64("account_id")
	}

	results, err := h.svc.GachaPull(c.Request.Context(), charID, req.Count)
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

// SetSkillSlot handles POST /api/skill/equip
func (h *SkillHandler) SetSkillSlot(c *gin.Context) {
	var req struct {
		Slot    int    `json:"slot" binding:"required"`
		SkillID string `json:"skill_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, errcode.Msg(errcode.ErrInvalidBody))
		return
	}

	charID := c.GetInt64("character_id")
	if charID == 0 {
		charID = c.GetInt64("account_id")
	}

	if err := h.svc.SetSkillSlot(c.Request.Context(), charID, req.Slot, req.SkillID); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrSkillSlotOccupied, err.Error())
		return
	}

	response.OK(c, nil)
}

// ListSkills handles GET /api/skill/list
func (h *SkillHandler) ListSkills(c *gin.Context) {
	charID := c.GetInt64("character_id")
	if charID == 0 {
		charID = c.GetInt64("account_id")
	}

	skills, err := h.svc.ListSkills(c.Request.Context(), charID)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, err.Error())
		return
	}

	response.OK(c, gin.H{"skills": skills})
}

// UpgradeSkill handles POST /api/skill/upgrade
func (h *SkillHandler) UpgradeSkill(c *gin.Context) {
	var req struct {
		SkillID string `json:"skill_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, errcode.Msg(errcode.ErrInvalidBody))
		return
	}

	charID := c.GetInt64("character_id")
	if charID == 0 {
		charID = c.GetInt64("account_id")
	}

	skill, err := h.svc.UpgradeSkill(c.Request.Context(), charID, req.SkillID)
	if err != nil {
		errMsg := err.Error()
		switch {
		case errMsg == "skill not found":
			response.Error(c, http.StatusBadRequest, errcode.ErrSkillNotFound, errMsg)
		case errMsg == "skill already max level":
			response.Error(c, http.StatusBadRequest, errcode.ErrSkillMaxLevel, errMsg)
		case errMsg[:22] == "insufficient cards for":
			response.Error(c, http.StatusBadRequest, errcode.ErrInsufficientCards, errMsg)
		default:
			response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, errMsg)
		}
		return
	}

	response.OK(c, skill)
}

// ShopInfo handles GET /api/skill/shop_info
func (h *SkillHandler) ShopInfo(c *gin.Context) {
	charID := c.GetInt64("character_id")
	if charID == 0 {
		charID = c.GetInt64("account_id")
	}

	info, err := h.svc.ShopInfo(c.Request.Context(), charID)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, err.Error())
		return
	}

	response.OK(c, info)
}
