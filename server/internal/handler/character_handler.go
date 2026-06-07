package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/adventure-game/server/internal/service"
	"github.com/adventure-game/server/pkg/errcode"
	"github.com/adventure-game/server/pkg/logger"
	"github.com/adventure-game/server/pkg/response"
)

type CharacterHandler struct {
	svc *service.CharacterService
}

func NewCharacterHandler(svc *service.CharacterService) *CharacterHandler {
	return &CharacterHandler{svc: svc}
}

// GetCharacter handles GET /api/character
func (h *CharacterHandler) GetCharacter(c *gin.Context) {
	accountID, exists := c.Get("account_id")
	if !exists {
		response.Error(c, http.StatusUnauthorized, errcode.ErrUnauthorized, errcode.Msg(errcode.ErrUnauthorized))
		return
	}

	logger.Info(c, "[GET_CHARACTER]")
	char, err := h.svc.GetByAccountID(c.Request.Context(), accountID.(int64))
	if err != nil {
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, errcode.Msg(errcode.ErrInternal))
		return
	}
	if char == nil {
		response.Error(c, http.StatusNotFound, errcode.ErrInternal, "character not found")
		return
	}

	response.OK(c, h.svc.ToResponse(char))
}

// AddExp handles POST /api/character/add_exp
func (h *CharacterHandler) AddExp(c *gin.Context) {
	var req struct {
		Exp int64 `json:"exp" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, errcode.Msg(errcode.ErrInvalidBody))
		return
	}

	charID := c.GetInt64("character_id")

	logger.Info(c, "[ADD_EXP]", "exp", req.Exp)
	char, err := h.svc.AddExp(c.Request.Context(), charID, req.Exp)
	if err != nil {
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, err.Error())
		return
	}

	response.OK(c, h.svc.ToResponse(char))
}
