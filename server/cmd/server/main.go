package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"

	"github.com/adventure-game/server/config"
	"github.com/adventure-game/server/internal/database"
	"github.com/adventure-game/server/internal/handler"
	"github.com/adventure-game/server/internal/middleware"
	"github.com/adventure-game/server/internal/repository"
	"github.com/adventure-game/server/internal/service"
	"github.com/adventure-game/server/pkg/response"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for development
	},
}

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
	characterRepo := repository.NewCharacterRepo(db)
	equipRepo := repository.NewEquipmentRepo(db)
	skillRepo := repository.NewSkillRepo(db)

	currencySvc := service.NewCurrencyService(characterRepo)

	accountSvc := service.NewAccountService(accountRepo, characterRepo, rdb, cfg.JWT)
	accountHandler := handler.NewAccountHandler(accountSvc)

	characterSvc := service.NewCharacterService(characterRepo)
	characterHandler := handler.NewCharacterHandler(characterSvc)

	equipSvc := service.NewEquipmentService(equipRepo, currencySvc)
	equipHandler := handler.NewEquipmentHandler(equipSvc)

	skillSvc := service.NewSkillService(skillRepo, characterRepo, currencySvc)
	skillHandler := handler.NewSkillHandler(skillSvc)

	chestSvc := service.NewChestService(characterRepo, equipRepo, equipSvc, currencySvc)
	chestHandler := handler.NewChestHandler(chestSvc)

	stageSvc := service.NewStageService(characterRepo)
	stageHandler := handler.NewStageHandler(stageSvc)

	battleSvc := service.NewBattleService(rdb)
	leaderboardSvc := service.NewLeaderboardService(rdb)
	leaderboardHandler := handler.NewLeaderboardHandler(leaderboardSvc)
	_ = battleSvc

	// --- Router ---
	r := gin.New()
	r.Use(middleware.Recovery())
	r.Use(middleware.Logger())
	r.Use(middleware.CORS())

	// Health check (DB + Redis)
	r.GET("/healthz", func(c *gin.Context) {
		if err := db.PingContext(c.Request.Context()); err != nil {
			response.Error(c, http.StatusServiceUnavailable, -1, "database unavailable")
			return
		}
		if err := rdb.Ping(c.Request.Context()).Err(); err != nil {
			response.Error(c, http.StatusServiceUnavailable, -1, "redis unavailable")
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

	// Character routes
	character := r.Group("/api/character")
	{
		character.GET("", characterHandler.GetCharacter)
		character.POST("/add_exp", characterHandler.AddExp)
	}

	// Equipment routes
	equipment := r.Group("/api/equipment")
	{
		equipment.GET("/inventory", equipHandler.GetInventory)
		equipment.POST("/equip", equipHandler.Equip)
		equipment.POST("/unequip", equipHandler.Unequip)
		equipment.POST("/decompose", equipHandler.Decompose)
	}

	// Skill routes
	skill := r.Group("/api/skill")
	{
		skill.GET("/list", skillHandler.ListSkills)
		skill.GET("/slots", skillHandler.GetSkillSlots)
		skill.POST("/gacha", skillHandler.Gacha)
		skill.POST("/equip", skillHandler.SetSkillSlot)
		skill.POST("/upgrade", skillHandler.UpgradeSkill)
		skill.GET("/shop_info", skillHandler.ShopInfo)
	}

	// Chest routes
	chest := r.Group("/api/chest")
	{
		chest.GET("/info", chestHandler.GetChestInfo)
		chest.POST("/open", chestHandler.OpenChest)
		chest.POST("/upgrade_zone", chestHandler.UpgradeZone)
	}

	// Stage routes
	stage := r.Group("/api/stage")
	{
		stage.GET("/start", stageHandler.GetStageConfig)
		stage.GET("/progress", stageHandler.GetProgress)
		stage.POST("/complete", stageHandler.ClaimRewards)
		stage.GET("/config", stageHandler.GetChapterStages)
	}

	// Leaderboard routes
	leaderboard := r.Group("/api/leaderboard")
	{
		leaderboard.GET("", leaderboardHandler.GetTop)
		leaderboard.GET("/my_rank", leaderboardHandler.GetMyRank)
	}

	// WebSocket battle endpoint
	r.GET("/ws/battle", middleware.Auth(cfg.JWT), func(c *gin.Context) {
		conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			slog.Error("websocket upgrade failed", "error", err)
			return
		}
		defer conn.Close()

		charID := c.GetInt64("character_id")
		slog.Info("battle websocket connected", "character_id", charID)

		for {
			_, message, err := conn.ReadMessage()
			if err != nil {
				slog.Info("websocket disconnected", "character_id", charID, "error", err)
				break
			}
			// Echo for now; battle processing handled by Plan A/B services
			if err := conn.WriteMessage(websocket.TextMessage, message); err != nil {
				break
			}
		}
	})

	slog.Info("server starting", "port", cfg.Server.Port)
	if err := r.Run(fmt.Sprintf(":%d", cfg.Server.Port)); err != nil {
		slog.Error("server failed", "error", err)
		os.Exit(1)
	}
}
