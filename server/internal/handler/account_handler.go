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
		Phone string `json:"phone"`
		Email string `json:"email"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, errcode.Msg(errcode.ErrInvalidBody))
		return
	}
	target := req.Phone
	if target == "" {
		target = req.Email
	}
	if target == "" {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, "phone or email required")
		return
	}

	if err := h.svc.SendVerificationCode(c.Request.Context(), target); err != nil {
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
// Accepts: phone/email/password/code/nickname
func (h *AccountHandler) Register(c *gin.Context) {
	var req service.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, errcode.Msg(errcode.ErrInvalidBody))
		return
	}

	tokens, err := h.svc.Register(c.Request.Context(), req)
	if err != nil {
		switch err.Error() {
		case "phone/email required":
			response.Error(c, http.StatusBadRequest, errcode.ErrPhoneRequired, errcode.Msg(errcode.ErrPhoneRequired))
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
// Accepts: account/password
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
