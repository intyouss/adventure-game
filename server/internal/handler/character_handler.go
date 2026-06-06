package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/adventure-game/server/internal/service"
	"github.com/adventure-game/server/pkg/errcode"
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
