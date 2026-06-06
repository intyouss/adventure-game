package response

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type Response struct {
	Code int         `json:"code"`
	Msg  string      `json:"msg"`
	Data interface{} `json:"data,omitempty"`
}

func OK(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, Response{Code: 0, Msg: "ok", Data: data})
}

func Error(c *gin.Context, httpStatus int, code int, msg string) {
	c.AbortWithStatusJSON(httpStatus, Response{Code: code, Msg: msg})
}
