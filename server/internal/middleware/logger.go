package middleware

import (
	"bytes"
	"io"
	"log/slog"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// responseWriter wraps gin.ResponseWriter to capture response body and status.
type responseWriter struct {
	gin.ResponseWriter
	body *bytes.Buffer
}

func (w *responseWriter) Write(b []byte) (int, error) {
	w.body.Write(b)
	return w.ResponseWriter.Write(b)
}

// Logger returns a middleware that logs every request and response with
// a consistent structured format suitable for agent tracing.
//
// Log format:
//
//	[REQ] id=uuid method=POST path=/api/xxx ip=1.2.3.4 query="k=v" body={...}
//	[RES] id=uuid method=POST path=/api/xxx status=200 latency=45ms code=0 msg=ok
//	[ERR] id=uuid method=POST path=/api/xxx status=2000 error="details"
func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		reqID := uuid.New().String()
		c.Set("request_id", reqID)

		start := time.Now()

		// Capture request body for logging (POST/PUT)
		var reqBody string
		if c.Request.Body != nil && (c.Request.Method == "POST" || c.Request.Method == "PUT") {
			bodyBytes, _ := io.ReadAll(c.Request.Body)
			c.Request.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
			if len(bodyBytes) > 0 {
				reqBody = string(bodyBytes)
				if len(reqBody) > 2000 {
					reqBody = reqBody[:2000] + "..."
				}
			}
		}

		// Log request
		slog.Info("[REQ]",
			"id", reqID,
			"method", c.Request.Method,
			"path", c.Request.URL.Path,
			"query", c.Request.URL.RawQuery,
			"ip", c.ClientIP(),
			"body", reqBody,
		)

		// Wrap response writer to capture response
		rw := &responseWriter{
			ResponseWriter: c.Writer,
			body:           bytes.NewBuffer(nil),
		}
		c.Writer = rw

		c.Next()

		latency := time.Since(start).Milliseconds()
		status := c.Writer.Status()

		// Truncate response body for logging
		respBody := rw.body.String()
		if len(respBody) > 2000 {
			respBody = respBody[:2000] + "..."
		}

		if status >= 400 {
			slog.Error("[RES]",
				"id", reqID,
				"method", c.Request.Method,
				"path", c.Request.URL.Path,
				"status", status,
				"latency_ms", latency,
				"body", respBody,
			)
		} else {
			slog.Info("[RES]",
				"id", reqID,
				"method", c.Request.Method,
				"path", c.Request.URL.Path,
				"status", status,
				"latency_ms", latency,
				"body", respBody,
			)
		}
	}
}
