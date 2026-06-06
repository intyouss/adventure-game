package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/adventure-game/server/internal/service"
	"github.com/adventure-game/server/pkg/errcode"
	"github.com/adventure-game/server/pkg/response"
)

type AccountHandler struct {
	svc *service.AccountService
}

func NewAccountHandler(svc *service.AccountService) *AccountHandler {
	return &AccountHandler{svc: svc}
}

// SendCode handles POST /api/auth/send_code
func (h *AccountHandler) SendCode(c *gin.Context) {
	var req struct {
		Target string `json:"target" binding:"required"`
		Type   string `json:"type" binding:"required,oneof=phone email"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, errcode.Msg(errcode.ErrInvalidBody))
		return
	}

	if err := h.svc.SendVerificationCode(c.Request.Context(), req.Target); err != nil {
		if err.Error() == "send code too frequent" {
			response.Error(c, http.StatusTooManyRequests, errcode.ErrSendTooFrequent, errcode.Msg(errcode.ErrSendTooFrequent))
			return
		}
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, errcode.Msg(errcode.ErrInternal))
		return
	}

	response.OK(c, nil)
}

// Register handles POST /api/auth/register
func (h *AccountHandler) Register(c *gin.Context) {
	var req service.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, errcode.Msg(errcode.ErrInvalidBody))
		return
	}

	tokens, err := h.svc.Register(c.Request.Context(), req)
	if err != nil {
		switch err.Error() {
		case "invalid target":
			response.Error(c, http.StatusBadRequest, errcode.ErrInvalidTarget, errcode.Msg(errcode.ErrInvalidTarget))
		case "already registered":
			response.Error(c, http.StatusConflict, errcode.ErrAlreadyRegistered, errcode.Msg(errcode.ErrAlreadyRegistered))
		case "invalid or expired code", "wrong code", "too many attempts":
			response.Error(c, http.StatusBadRequest, errcode.ErrInvalidCode, errcode.Msg(errcode.ErrInvalidCode))
		default:
			response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, errcode.Msg(errcode.ErrInternal))
		}
		return
	}

	response.OK(c, tokens)
}

// Login handles POST /api/auth/login
func (h *AccountHandler) Login(c *gin.Context) {
	var req service.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, errcode.Msg(errcode.ErrInvalidBody))
		return
	}

	tokens, err := h.svc.Login(c.Request.Context(), req)
	if err != nil {
		switch err.Error() {
		case "account not found":
			response.Error(c, http.StatusNotFound, errcode.ErrAccountNotFound, errcode.Msg(errcode.ErrAccountNotFound))
		case "wrong password":
			response.Error(c, http.StatusUnauthorized, errcode.ErrWrongPassword, errcode.Msg(errcode.ErrWrongPassword))
		default:
			response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, errcode.Msg(errcode.ErrInternal))
		}
		return
	}

	response.OK(c, tokens)
}

// RefreshToken handles POST /api/auth/refresh
func (h *AccountHandler) RefreshToken(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refresh_token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, errcode.Msg(errcode.ErrInvalidBody))
		return
	}

	tokens, err := h.svc.RefreshAccessToken(c.Request.Context(), req.RefreshToken)
	if err != nil {
		if err.Error() == "invalid refresh token" {
			response.Error(c, http.StatusUnauthorized, errcode.ErrInvalidRefresh, errcode.Msg(errcode.ErrInvalidRefresh))
			return
		}
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, errcode.Msg(errcode.ErrInternal))
		return
	}

	response.OK(c, tokens)
}
