package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/adventure-game/server/config"
	"github.com/adventure-game/server/pkg/errcode"
	"github.com/adventure-game/server/pkg/jwt"
	"github.com/adventure-game/server/pkg/response"
)

// Auth returns a middleware that validates JWT access tokens.
func Auth(jwtCfg config.JWTConfig) gin.HandlerFunc {
	skipPaths := map[string]bool{
		"/api/auth/send_code": true,
		"/api/auth/register":  true,
		"/api/auth/login":     true,
		"/api/auth/refresh":   true,
		"/healthz":            true,
	}

	return func(c *gin.Context) {
		path := strings.TrimRight(c.Request.URL.Path, "/")
		if path == "" {
			path = "/"
		}
		if skipPaths[path] {
			c.Next()
			return
		}

		authHeader := c.GetHeader("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			response.Error(c, http.StatusUnauthorized, errcode.ErrUnauthorized, errcode.Msg(errcode.ErrUnauthorized))
			c.Abort()
			return
		}

		tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
		claims, err := jwt.Parse(jwtCfg.Secret, tokenStr)
		if err != nil {
			response.Error(c, http.StatusUnauthorized, errcode.ErrUnauthorized, errcode.Msg(errcode.ErrUnauthorized))
			c.Abort()
			return
		}

		c.Set("account_id", claims.AccountID)
		c.Set("character_id", claims.CharacterID)
		c.Next()
	}
}
