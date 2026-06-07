package logger

import (
	"log/slog"

	"github.com/gin-gonic/gin"
)

// FromContext returns a logger with request_id and optional character_id
// from the Gin context, suitable for structured agent-traceable logging.
func FromContext(c *gin.Context) *slog.Logger {
	attrs := []any{}

	if reqID, ok := c.Get("request_id"); ok {
		attrs = append(attrs, "request_id", reqID)
	}
	if charID := c.GetInt64("character_id"); charID != 0 {
		attrs = append(attrs, "character_id", charID)
	}

	return slog.With(attrs...)
}

// Info logs at info level with request context.
func Info(c *gin.Context, msg string, args ...any) {
	FromContext(c).Info(msg, args...)
}

// Error logs at error level with request context.
func Error(c *gin.Context, msg string, args ...any) {
	FromContext(c).Error(msg, args...)
}

// Warn logs at warn level with request context.
func Warn(c *gin.Context, msg string, args ...any) {
	FromContext(c).Warn(msg, args...)
}

// Debug logs at debug level with request context.
func Debug(c *gin.Context, msg string, args ...any) {
	FromContext(c).Debug(msg, args...)
}
