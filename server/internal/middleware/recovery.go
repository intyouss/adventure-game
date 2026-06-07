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
				reqID, _ := c.Get("request_id")
				slog.Error("[PANIC]",
					"id", reqID,
					"error", err,
					"method", c.Request.Method,
					"path", c.Request.URL.Path,
				)
				response.Error(c, http.StatusInternalServerError, -1, "internal server error")
			}
		}()
		c.Next()
	}
}
