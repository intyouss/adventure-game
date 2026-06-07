package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/adventure-game/server/internal/service"
	"github.com/adventure-game/server/pkg/errcode"
	"github.com/adventure-game/server/pkg/logger"
	"github.com/adventure-game/server/pkg/response"
)

type AccountHandler struct {
	svc *service.AccountService
}

func NewAccountHandler(svc *service.AccountService) *AccountHandler {
	return &AccountHandler{svc: svc}
}

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

	logger.Info(c, "[SEND_CODE]", "target", target)

	if err := h.svc.SendVerificationCode(c.Request.Context(), target); err != nil {
		if err.Error() == "send code too frequent" {
			logger.Warn(c, "[SEND_CODE] too frequent", "target", target)
			response.Error(c, http.StatusTooManyRequests, errcode.ErrSendTooFrequent, errcode.Msg(errcode.ErrSendTooFrequent))
			return
		}
		logger.Error(c, "[SEND_CODE] failed", "target", target, "error", err)
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, errcode.Msg(errcode.ErrInternal))
		return
	}

	logger.Info(c, "[SEND_CODE] success", "target", target)
	response.OK(c, nil)
}

func (h *AccountHandler) Register(c *gin.Context) {
	var req service.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, errcode.Msg(errcode.ErrInvalidBody))
		return
	}

	if len(req.Password) < 6 || len(req.Password) > 32 {
		response.Error(c, http.StatusBadRequest, errcode.ErrInvalidPassword, "password must be 6-32 characters")
		return
	}

	if req.Nickname != "" && (len(req.Nickname) < 2 || len(req.Nickname) > 12) {
		response.Error(c, http.StatusBadRequest, errcode.ErrNicknameInvalid, errcode.Msg(errcode.ErrNicknameInvalid))
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
			logger.Error(c, "[REGISTER] failed", "error", err)
			response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, errcode.Msg(errcode.ErrInternal))
		}
		return
	}

	logger.Info(c, "[REGISTER] success", "character_id", tokens.CharacterID)
	response.OK(c, tokens)
}

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
			logger.Warn(c, "[LOGIN] account not found", "account", req.Account)
			response.Error(c, http.StatusNotFound, errcode.ErrAccountNotFound, errcode.Msg(errcode.ErrAccountNotFound))
		case "wrong password":
			logger.Warn(c, "[LOGIN] wrong password", "account", req.Account)
			response.Error(c, http.StatusUnauthorized, errcode.ErrWrongPassword, errcode.Msg(errcode.ErrWrongPassword))
		case "invalid or expired code", "wrong code", "too many attempts":
			logger.Warn(c, "[LOGIN] invalid code", "account", req.Account)
			response.Error(c, http.StatusBadRequest, errcode.ErrInvalidCode, errcode.Msg(errcode.ErrInvalidCode))
		case "password or code required":
			logger.Warn(c, "[LOGIN] missing credentials", "account", req.Account)
			response.Error(c, http.StatusBadRequest, errcode.ErrInvalidBody, "password or code required")
		default:
			logger.Error(c, "[LOGIN] failed", "error", err)
			response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, errcode.Msg(errcode.ErrInternal))
		}
		return
	}

	logger.Info(c, "[LOGIN] success", "character_id", tokens.CharacterID)
	response.OK(c, tokens)
}

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
			logger.Warn(c, "[REFRESH] invalid token")
			response.Error(c, http.StatusUnauthorized, errcode.ErrInvalidRefresh, errcode.Msg(errcode.ErrInvalidRefresh))
			return
		}
		logger.Error(c, "[REFRESH] failed", "error", err)
		response.Error(c, http.StatusInternalServerError, errcode.ErrInternal, errcode.Msg(errcode.ErrInternal))
		return
	}

	logger.Info(c, "[REFRESH] success", "character_id", tokens.CharacterID)
	response.OK(c, tokens)
}
