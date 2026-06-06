package middleware

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/adventure-game/server/pkg/response"
)

func Recovery() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				slog.Error("panic recovered", "error", err, "path", c.Request.URL.Path)
				response.Error(c, http.StatusInternalServerError, -1, "internal server error")
			}
		}()
		c.Next()
	}
}
