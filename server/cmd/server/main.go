package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"

	"github.com/gin-gonic/gin"

	"github.com/adventure-game/server/config"
	"github.com/adventure-game/server/internal/database"
	"github.com/adventure-game/server/internal/handler"
	"github.com/adventure-game/server/internal/middleware"
	"github.com/adventure-game/server/internal/repository"
	"github.com/adventure-game/server/internal/service"
	"github.com/adventure-game/server/pkg/response"
)

func main() {
	cfg, err := config.Load("config/config.yaml")
	if err != nil {
		slog.Error("load config", "error", err)
		os.Exit(1)
	}

	db, err := database.NewPostgres(cfg.Database)
	if err != nil {
		slog.Error("connect postgres", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	if err := database.RunMigrations(context.Background(), db, "migrations"); err != nil {
		slog.Error("run migrations", "error", err)
		os.Exit(1)
	}

	rdb, err := database.NewRedis(cfg.Redis)
	if err != nil {
		slog.Error("connect redis", "error", err)
		os.Exit(1)
	}
	defer rdb.Close()

	// --- Dependency injection ---
	accountRepo := repository.NewAccountRepo(db)
	accountSvc := service.NewAccountService(accountRepo, rdb, cfg.JWT)
	accountHandler := handler.NewAccountHandler(accountSvc)

	// --- Router ---
	r := gin.New()
	r.Use(middleware.Recovery())
	r.Use(middleware.Logger())
	r.Use(middleware.CORS())

	r.GET("/healthz", func(c *gin.Context) {
		if err := db.PingContext(c.Request.Context()); err != nil {
			response.Error(c, 503, -1, "database unavailable")
			return
		}
		if err := rdb.Ping(c.Request.Context()).Err(); err != nil {
			response.Error(c, 503, -1, "redis unavailable")
			return
		}
		response.OK(c, gin.H{"status": "healthy"})
	})

	// Auth routes (no JWT required)
	auth := r.Group("/api/auth")
	{
		auth.POST("/send_code", accountHandler.SendCode)
		auth.POST("/register", accountHandler.Register)
		auth.POST("/login", accountHandler.Login)
		auth.POST("/refresh", accountHandler.RefreshToken)
	}

	// JWT auth middleware for protected routes
	r.Use(middleware.Auth(cfg.JWT))

	slog.Info("server starting", "port", cfg.Server.Port)
	if err := r.Run(fmt.Sprintf(":%d", cfg.Server.Port)); err != nil {
		slog.Error("server failed", "error", err)
		os.Exit(1)
	}
}
