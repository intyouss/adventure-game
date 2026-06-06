# 冒险大作战 — 实施计划

> **For agentic workers:** 使用 superpowers:subagent-driven-development (推荐) 或 superpowers:executing-plans 按任务逐步实施。步骤使用 checkbox (`- [ ]`) 格式追踪。

**目标:** 从零构建《冒险大作战》完整可玩的 PvE 放置 RPG 游戏（Go 后端 + Godot 客户端 + PostgreSQL + Redis）

**架构:** 分层渐进式实施 — 先搭后端基础设施，再逐个模块 TDD 开发，最后构建 Godot 客户端并前后端联调。每个模块独立可测、独立可交付。

**技术栈:** Go 1.26 + Gin + PostgreSQL 16 + Redis 7 + JWT + WebSocket | Godot 4.x (GDScript)

**设计文档基线:** proposal.md v1.1 / high-level-design.md v1.0 / detailed-design.md v1.0

---

## 实施阶段总览

| 阶段 | 模块 | 预估工时 | 产出 |
|------|------|----------|------|
| 0 | 项目脚手架 & 基础设施 | 2h | 可运行的空服务 + DB/Redis 连通 |
| 1 | 账号模块 | 4h | 注册/登录/Token 刷新 |
| 2 | 角色模块 | 3h | 创建角色/属性/升级 |
| 3 | 装备模块 | 4h | 装备仓库/穿戴/分解 |
| 4 | 技能模块 | 4h | Gacha 抽取/技能仓库/槽位 |
| 5 | 开箱模块 | 2h | 开箱/区域升级 |
| 6 | 关卡模块 | 2h | 关卡配置/进度/解锁 |
| 7 | 货币模块 | 1.5h | 金币/技能券 原子操作 |
| 8 | 战斗校验模块 | 5h | Plan A+B / Redis Streams |
| 9 | 排行榜模块 | 2h | Redis Sorted Set 排行榜 |
| 10 | 集成 & 路由注册 | 2h | 全模块串联/端到端测试 |
| 11 | Godot 客户端 | 8h | 所有 UI 场景/战斗/网络通信 |
| 12 | 前后端联调 | 3h | 端到端跑通 |

---

## Phase 0: 项目脚手架 & 基础设施

**目标:** 创建 Go 项目骨架、数据库连接、Redis 连接、Gin 路由 + 中间件链、健康检查端点。

### Task 0.1: 初始化 Go 模块和目录结构

**Files:**
- Create: `server/go.mod`
- Create: `server/main.go`
- Create: `server/config/config.go`
- Create: `server/config/config.yaml`
- Create: `server/internal/database/postgres.go`
- Create: `server/internal/database/redis.go`
- Create: `server/pkg/response/response.go`
- Create: `server/pkg/errcode/errcode.go`
- Create: `docker-compose.yml`

- [ ] **Step 1: 创建 docker-compose.yml**

```yaml
version: "3.9"
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: adventurer
      POSTGRES_PASSWORD: adventurer_dev
      POSTGRES_DB: adventure_game
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  pgdata:
```

- [ ] **Step 2: 初始化 Go Module**

```bash
cd server && go mod init github.com/adventure-game/server
```

- [ ] **Step 3: 创建 config/config.go**

```go
package config

import (
    "os"
    "gopkg.in/yaml.v3"
)

type Config struct {
    Server   ServerConfig   `yaml:"server"`
    Database DatabaseConfig `yaml:"database"`
    Redis    RedisConfig    `yaml:"redis"`
    JWT      JWTConfig      `yaml:"jwt"`
}

type ServerConfig struct {
    Port int `yaml:"port"`
}

type DatabaseConfig struct {
    Host     string `yaml:"host"`
    Port     int    `yaml:"port"`
    User     string `yaml:"user"`
    Password string `yaml:"password"`
    DBName   string `yaml:"dbname"`
    SSLMode  string `yaml:"sslmode"`
}

func (d DatabaseConfig) DSN() string {
    return fmt.Sprintf(
        "host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
        d.Host, d.Port, d.User, d.Password, d.DBName, d.SSLMode,
    )
}

type RedisConfig struct {
    Addr     string `yaml:"addr"`
    Password string `yaml:"password"`
    DB       int    `yaml:"db"`
}

type JWTConfig struct {
    Secret        string `yaml:"secret"`
    AccessTTL     int    `yaml:"access_ttl"`
}

func Load(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }
    cfg := &Config{}
    if err := yaml.Unmarshal(data, cfg); err != nil {
        return nil, err
    }
    if cfg.Server.Port == 0 {
        cfg.Server.Port = 8080
    }
    return cfg, nil
}
```

- [ ] **Step 4: 创建 config/config.yaml**

```yaml
server:
  port: 8080

database:
  host: localhost
  port: 5432
  user: adventurer
  password: adventurer_dev
  dbname: adventure_game
  sslmode: disable

redis:
  addr: localhost:6379
  password: ""
  db: 0

jwt:
  secret: "change-me-in-production-use-256-bit-random"
  access_ttl: 7200
```

- [ ] **Step 5: 创建 pkg/response/response.go**

```go
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
```

- [ ] **Step 6: 创建 pkg/errcode/errcode.go**

```go
package errcode

const (
    // 通用
    ErrInternal         = -1
    ErrInvalidTarget    = 10001
    ErrSendTooFrequent  = 10002
    ErrPhoneRequired    = 10003
    ErrInvalidPassword  = 10004
    ErrAlreadyRegistered = 10005
    ErrInvalidCode      = 10006
    ErrNicknameInvalid  = 10007
    ErrAccountNotFound  = 10008
    ErrWrongPassword    = 10009
    ErrLoginTooFrequent = 10010
    ErrInvalidRefresh   = 10011
    ErrRefreshExpired   = 10012
    ErrUnauthorized     = 10013
    ErrRateLimited      = 10014
    ErrInvalidBody      = 10015

    // 装备
    ErrItemNotFound     = 30001
    ErrSlotMismatch     = 30002
    ErrSlotOccupied     = 30003
    ErrItemEquipped     = 30004
    ErrItemNotInInv     = 30005

    // 技能
    ErrInsufficientTicket = 40001
    ErrInvalidCount     = 40002
    ErrSkillNotFound    = 40003
    ErrSkillSlotOccupied = 40004
    ErrInsufficientCards = 40005
    ErrSkillMaxLevel    = 40006

    // 开箱
    ErrInsufficientChests = 50001
    ErrInsufficientGold   = 50002
    ErrZoneMaxLevel       = 50003

    // 关卡
    ErrStageNotFound     = 60001
    ErrStageNotUnlocked  = 60002

    // 战斗
    ErrPlanAFailed       = 70001
    ErrPlanBFailed       = 70002
    ErrSummaryInvalid    = 70003
)

var Messages = map[int]string{
    ErrInternal:          "internal server error",
    ErrInvalidTarget:     "invalid target format",
    ErrSendTooFrequent:   "send code too frequent",
    ErrPhoneRequired:     "phone or email required",
    ErrInvalidPassword:   "invalid password format",
    ErrAlreadyRegistered: "already registered",
    ErrInvalidCode:       "invalid or expired code",
    ErrNicknameInvalid:   "nickname too short or too long",
    ErrAccountNotFound:   "account not found",
    ErrWrongPassword:     "wrong password",
    ErrLoginTooFrequent:  "login too frequent",
    ErrInvalidRefresh:    "invalid refresh token",
    ErrRefreshExpired:    "refresh token expired",
    ErrUnauthorized:      "unauthorized",
    ErrRateLimited:       "rate limit exceeded",
    ErrInvalidBody:       "invalid request body",
    ErrItemNotFound:      "item not found",
    ErrSlotMismatch:      "slot mismatch",
    ErrSlotOccupied:      "slot already occupied",
    ErrItemEquipped:      "item is equipped, unequip first",
    ErrItemNotInInv:      "item not in inventory",
    ErrInsufficientTicket:"insufficient skill tickets",
    ErrInvalidCount:      "invalid count",
    ErrSkillNotFound:     "skill not found",
    ErrSkillSlotOccupied: "skill slot occupied",
    ErrInsufficientCards: "insufficient cards for upgrade",
    ErrSkillMaxLevel:     "skill already max level",
    ErrInsufficientChests:"insufficient chests",
    ErrInsufficientGold:  "insufficient gold",
    ErrZoneMaxLevel:      "zone already max level",
    ErrStageNotFound:     "stage not found",
    ErrStageNotUnlocked:  "stage not unlocked",
    ErrPlanAFailed:       "verification failed (plan A)",
    ErrPlanBFailed:       "verification failed (plan B)",
    ErrSummaryInvalid:    "battle summary invalid",
}

func Msg(code int) string {
    if m, ok := Messages[code]; ok {
        return m
    }
    return "unknown error"
}
```

- [ ] **Step 7: 创建 internal/database/postgres.go**

```go
package database

import (
    "database/sql"
    "fmt"
    _ "github.com/lib/pq"
    "github.com/adventure-game/server/config"
)

func NewPostgres(cfg config.DatabaseConfig) (*sql.DB, error) {
    db, err := sql.Open("postgres", cfg.DSN())
    if err != nil {
        return nil, fmt.Errorf("open postgres: %w", err)
    }
    db.SetMaxOpenConns(25)
    db.SetMaxIdleConns(5)
    if err := db.Ping(); err != nil {
        return nil, fmt.Errorf("ping postgres: %w", err)
    }
    return db, nil
}
```

- [ ] **Step 8: 创建 internal/database/redis.go**

```go
package database

import (
    "context"
    "fmt"
    "github.com/redis/go-redis/v9"
    "github.com/adventure-game/server/config"
)

func NewRedis(cfg config.RedisConfig) (*redis.Client, error) {
    rdb := redis.NewClient(&redis.Options{
        Addr:     cfg.Addr,
        Password: cfg.Password,
        DB:       cfg.DB,
    })
    if err := rdb.Ping(context.Background()).Err(); err != nil {
        return nil, fmt.Errorf("ping redis: %w", err)
    }
    return rdb, nil
}
```

- [ ] **Step 9: 安装依赖 & 编译验证**

```bash
cd server
go get github.com/gin-gonic/gin
go get github.com/lib/pq
go get github.com/redis/go-redis/v9
go get gopkg.in/yaml.v3
go get github.com/golang-jwt/jwt/v5
go get golang.org/x/crypto
go mod tidy
go build ./...
```

预期: 编译成功，无错误。

### Task 0.2: 创建 Gin 路由 + 中间件链 + 主入口

**Files:**
- Create: `server/internal/middleware/recovery.go`
- Create: `server/internal/middleware/logger.go`
- Create: `server/internal/middleware/cors.go`
- Create: `server/cmd/server/main.go`

- [ ] **Step 1: 创建 internal/middleware/recovery.go**

```go
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
```

- [ ] **Step 2: 创建 internal/middleware/logger.go**

```go
package middleware

import (
    "log/slog"
    "time"
    "github.com/gin-gonic/gin"
)

func Logger() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        c.Next()
        slog.Info("request",
            "method", c.Request.Method,
            "path", c.Request.URL.Path,
            "status", c.Writer.Status(),
            "latency_ms", time.Since(start).Milliseconds(),
        )
    }
}
```

- [ ] **Step 3: 创建 internal/middleware/cors.go**

```go
package middleware

import (
    "github.com/gin-gonic/gin"
)

func CORS() gin.HandlerFunc {
    return func(c *gin.Context) {
        c.Header("Access-Control-Allow-Origin", "*")
        c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
        c.Header("Access-Control-Allow-Headers", "Authorization,Content-Type")
        if c.Request.Method == "OPTIONS" {
            c.AbortWithStatus(204)
            return
        }
        c.Next()
    }
}
```

- [ ] **Step 4: 创建 cmd/server/main.go**

```go
package main

import (
    "log/slog"
    "os"
    "github.com/gin-gonic/gin"
    "github.com/adventure-game/server/config"
    "github.com/adventure-game/server/internal/database"
    "github.com/adventure-game/server/internal/middleware"
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

    rdb, err := database.NewRedis(cfg.Redis)
    if err != nil {
        slog.Error("connect redis", "error", err)
        os.Exit(1)
    }
    defer rdb.Close()

    r := gin.New()
    r.Use(middleware.Recovery())
    r.Use(middleware.Logger())
    r.Use(middleware.CORS())

    r.GET("/healthz", func(c *gin.Context) {
        if err := db.Ping(); err != nil {
            response.Error(c, 503, -1, "database unavailable")
            return
        }
        if err := rdb.Ping(c.Request.Context()).Err(); err != nil {
            response.Error(c, 503, -1, "redis unavailable")
            return
        }
        response.OK(c, gin.H{"status": "healthy"})
    })

    slog.Info("server starting", "port", cfg.Server.Port)
    if err := r.Run(":8080"); err != nil {
        slog.Error("server failed", "error", err)
        os.Exit(1)
    }
}
```

- [ ] **Step 5: 编译**

```bash
cd server && go build -o bin/server ./cmd/server/
```

预期: 编译成功。

---

## Phase 1: 账号模块

**目标:** 注册（手机/邮箱 + 验证码）、登录、JWT 双 Token 签发与刷新。

### Task 1.1: 数据库 Migration — accounts 表

**Files:**
- Create: `server/migrations/001_create_accounts.up.sql`
- Create: `server/migrations/001_create_accounts.down.sql`

- [ ] **Step 1: 创建 up migration**

```sql
CREATE TABLE IF NOT EXISTS accounts (
    id            BIGSERIAL PRIMARY KEY,
    phone         VARCHAR(20),
    email         VARCHAR(255),
    password_hash VARCHAR(255) NOT NULL,
    created_at    TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT chk_contact CHECK (phone IS NOT NULL OR email IS NOT NULL)
);

CREATE UNIQUE INDEX idx_accounts_phone ON accounts(phone) WHERE phone IS NOT NULL;
CREATE UNIQUE INDEX idx_accounts_email ON accounts(email) WHERE email IS NOT NULL;
```

- [ ] **Step 2: 创建 down migration**

```sql
DROP TABLE IF EXISTS accounts;
```

### Task 1.2: 密码哈希工具 (argon2id)

**Files:**
- Create: `server/pkg/password/argon2.go`
- Create: `server/pkg/password/argon2_test.go`

- [ ] **Step 1: 写测试 — argon2_test.go**

```go
package password

import "testing"

func TestHashAndVerify(t *testing.T) {
    pw := "mySecureP@ss123"
    hash, err := Hash(pw)
    if err != nil {
        t.Fatalf("Hash() error = %v", err)
    }
    if hash == "" {
        t.Fatal("Hash() returned empty string")
    }
    if hash == pw {
        t.Fatal("Hash() returned plaintext")
    }

    if !Verify(pw, hash) {
        t.Fatal("Verify() failed for correct password")
    }
    if Verify("wrongpassword", hash) {
        t.Fatal("Verify() passed for wrong password")
    }
}

func TestHashDeterministic(t *testing.T) {
    pw := "test"
    h1, _ := Hash(pw)
    h2, _ := Hash(pw)
    if h1 == h2 {
        t.Fatal("Hash() should produce different salts each time")
    }
}
```

- [ ] **Step 2: 运行测试 → 失败**

```bash
cd server && go test ./pkg/password/ -v
```

- [ ] **Step 3: 实现 argon2.go**

```go
package password

import (
    "crypto/rand"
    "crypto/subtle"
    "encoding/base64"
    "fmt"
    "strings"
    "golang.org/x/crypto/argon2"
)

type params struct {
    memory      uint32
    iterations  uint32
    parallelism uint8
    saltLen     uint32
    keyLen      uint32
}

var p = params{
    memory:      64 * 1024,
    iterations:  3,
    parallelism: 4,
    saltLen:     16,
    keyLen:      32,
}

func Hash(password string) (string, error) {
    salt := make([]byte, p.saltLen)
    if _, err := rand.Read(salt); err != nil {
        return "", err
    }
    hash := argon2.IDKey([]byte(password), salt, p.iterations, p.memory, p.parallelism, p.keyLen)
    b64Salt := base64.RawStdEncoding.EncodeToString(salt)
    b64Hash := base64.RawStdEncoding.EncodeToString(hash)
    return fmt.Sprintf("$argon2id$v=19$m=%d,t=%d,p=%d$%s$%s",
        p.memory, p.iterations, p.parallelism, b64Salt, b64Hash), nil
}

func Verify(password, encodedHash string) bool {
    parts := strings.Split(encodedHash, "$")
    if len(parts) != 6 {
        return false
    }
    var memory uint32
    var iterations uint32
    var parallelism uint8
    fmt.Sscanf(parts[3], "m=%d,t=%d,p=%d", &memory, &iterations, &parallelism)

    salt, _ := base64.RawStdEncoding.DecodeString(parts[4])
    hash, _ := base64.RawStdEncoding.DecodeString(parts[5])

    candidate := argon2.IDKey([]byte(password), salt, iterations, memory, parallelism, uint32(len(hash)))
    return subtle.ConstantTimeCompare(hash, candidate) == 1
}
```

- [ ] **Step 4: 运行测试 → 通过**

```bash
go test ./pkg/password/ -v
```

- [ ] **Step 5: Commit**

```bash
git add server/pkg/password/ && git commit -m "feat: add argon2id password hashing"
```

### Task 1.3: JWT 工具

**Files:**
- Create: `server/pkg/jwt/jwt.go`
- Create: `server/pkg/jwt/jwt_test.go`

- [ ] **Step 1: 写测试 — jwt_test.go**

```go
package jwt

import (
    "testing"
    "time"
)

func TestGenerateAndParse(t *testing.T) {
    secret := "test-secret-32-bytes-long!!!!!"
    accountID := int64(1)
    characterID := int64(100)

    token, err := Generate(secret, accountID, characterID, 3600)
    if err != nil {
        t.Fatalf("Generate() error = %v", err)
    }
    if token == "" {
        t.Fatal("Generate() returned empty token")
    }

    claims, err := Parse(secret, token)
    if err != nil {
        t.Fatalf("Parse() error = %v", err)
    }
    if claims.AccountID != accountID {
        t.Errorf("AccountID = %d, want %d", claims.AccountID, accountID)
    }
    if claims.CharacterID != characterID {
        t.Errorf("CharacterID = %d, want %d", claims.CharacterID, characterID)
    }
}

func TestExpiredToken(t *testing.T) {
    secret := "test-secret-32-bytes-long!!!!!"
    token, _ := Generate(secret, 1, 1, -1) // 已过期
    _, err := Parse(secret, token)
    if err == nil {
        t.Fatal("Parse() should fail for expired token")
    }
}

func TestWrongSecret(t *testing.T) {
    token, _ := Generate("secret-a", 1, 1, 3600)
    _, err := Parse("secret-b", token)
    if err == nil {
        t.Fatal("Parse() should fail with wrong secret")
    }
}
```

- [ ] **Step 2: 实现 jwt.go**

```go
package jwt

import (
    "fmt"
    "time"
    "github.com/golang-jwt/jwt/v5"
)

type Claims struct {
    jwt.RegisteredClaims
    AccountID   int64 `json:"aid"`
    CharacterID int64 `json:"cid"`
}

func Generate(secret string, accountID, characterID int64, ttlSeconds int) (string, error) {
    now := time.Now()
    claims := Claims{
        RegisteredClaims: jwt.RegisteredClaims{
            IssuedAt:  jwt.NewNumericDate(now),
            ExpiresAt: jwt.NewNumericDate(now.Add(time.Duration(ttlSeconds) * time.Second)),
        },
        AccountID:   accountID,
        CharacterID: characterID,
    }
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString([]byte(secret))
}

func Parse(secret, tokenStr string) (*Claims, error) {
    token, err := jwt.ParseWithClaims(tokenStr, &Claims{},
        func(t *jwt.Token) (interface{}, error) {
            if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
                return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
            }
            return []byte(secret), nil
        },
    )
    if err != nil {
        return nil, err
    }
    claims, ok := token.Claims.(*Claims)
    if !ok || !token.Valid {
        return nil, fmt.Errorf("invalid token")
    }
    return claims, nil
}
```

- [ ] **Step 3: 运行测试 → 通过**

```bash
go test ./pkg/jwt/ -v
```

- [ ] **Step 4: Commit**

```bash
git add server/pkg/jwt/ && git commit -m "feat: add JWT token generation and parsing"
```

### Task 1.4: Account Repository

**Files:**
- Create: `server/internal/model/account.go`
- Create: `server/internal/repository/account_repo.go`
- Create: `server/internal/repository/account_repo_test.go`

- [ ] **Step 1: 创建 model**

```go
// server/internal/model/account.go
package model

import "time"

type Account struct {
    ID           int64     `json:"id"           db:"id"`
    Phone        string    `json:"phone"        db:"phone"`
    Email        string    `json:"email"        db:"email"`
    PasswordHash string    `json:"-"            db:"password_hash"`
    CreatedAt    time.Time `json:"created_at"   db:"created_at"`
}
```

- [ ] **Step 2: 创建 account_repo.go**

```go
package repository

import (
    "database/sql"
    "github.com/adventure-game/server/internal/model"
)

type AccountRepo struct {
    db *sql.DB
}

func NewAccountRepo(db *sql.DB) *AccountRepo {
    return &AccountRepo{db: db}
}

func (r *AccountRepo) Create(account *model.Account) error {
    return r.db.QueryRow(
        `INSERT INTO accounts (phone, email, password_hash) VALUES ($1, $2, $3) RETURNING id, created_at`,
        account.Phone, account.Email, account.PasswordHash,
    ).Scan(&account.ID, &account.CreatedAt)
}

func (r *AccountRepo) FindByPhone(phone string) (*model.Account, error) {
    a := &model.Account{}
    err := r.db.QueryRow(
        `SELECT id, phone, email, password_hash, created_at FROM accounts WHERE phone = $1`,
        phone,
    ).Scan(&a.ID, &a.Phone, &a.Email, &a.PasswordHash, &a.CreatedAt)
    if err == sql.ErrNoRows {
        return nil, nil
    }
    return a, err
}

func (r *AccountRepo) FindByEmail(email string) (*model.Account, error) {
    a := &model.Account{}
    err := r.db.QueryRow(
        `SELECT id, phone, email, password_hash, created_at FROM accounts WHERE email = $1`,
        email,
    ).Scan(&a.ID, &a.Phone, &a.Email, &a.PasswordHash, &a.CreatedAt)
    if err == sql.ErrNoRows {
        return nil, nil
    }
    return a, err
}

func (r *AccountRepo) FindByID(id int64) (*model.Account, error) {
    a := &model.Account{}
    err := r.db.QueryRow(
        `SELECT id, phone, email, password_hash, created_at FROM accounts WHERE id = $1`,
        id,
    ).Scan(&a.ID, &a.Phone, &a.Email, &a.PasswordHash, &a.CreatedAt)
    if err == sql.ErrNoRows {
        return nil, nil
    }
    return a, err
}
```

- [ ] **Step 3: Commit**

```bash
git add server/internal/model/ server/internal/repository/ && git commit -m "feat: add account model and repository"
```

### Task 1.5: Account Service + 验证码 (Redis)

**Files:**
- Create: `server/internal/service/account_svc.go`
- Create: `server/internal/handler/account_handler.go`

由于篇幅限制，Phase 1 其余任务（验证码 Redis 服务、注册/登录/刷新 Handler、Auth 中间件、路由注册）以及 Phase 2-12 的详细步骤将在实施时按需展开。

Phase 1 关键后续步骤大纲：
- Task 1.6: AccountService（注册逻辑：校验验证码 → 哈希密码 → 创建账号 → 签发 Token）
- Task 1.7: AccountHandler（POST /api/auth/send_code, /register, /login, /refresh）
- Task 1.8: JWT Auth Middleware（白名单 + Bearer Token 解析 + Context 注入）
- Task 1.9: 路由注册 + 集成测试

---

## Phase 2: 角色模块

**目标:** 创建角色、属性计算、经验升级、战力 CP 计算。

关键文件：
- `server/migrations/002_create_characters.up.sql`
- `server/internal/model/character.go`
- `server/internal/repository/character_repo.go`
- `server/internal/service/character_svc.go`
- `server/internal/handler/character_handler.go`

核心实现：
- 注册后自动创建角色（默认 warrior 职业，Lv1，初始属性）
- `CalcStats(level int) FinalStats` — 等级→属性映射
- `AddExp(charID, exp int64)` — 经验增加 + 自动升级
- `CalcCP(stats FinalStats) float64` — DPS 战力公式
- `ExpToNextLevel(level int) int64` — 指数经验曲线 `100 * 1.15^(level-1)`

---

## Phase 3: 装备模块

**目标:** 装备仓库 JSONB、穿戴/卸下、分解、随机属性生成。

关键模型：
```go
type Equipment struct {
    ID      string `json:"id"`
    Slot    string `json:"slot"`
    Quality int    `json:"quality"`
    ATK     int    `json:"atk"`
    DEF     int    `json:"def"`
    HP      int    `json:"hp"`
}
```

核心实现：
- `EquipmentRepo` — JSONB 操作（`equipments` 和 `equipped` 字段在同一行锁下）
- 装备/卸下：`Equip(charID, equipID)` / `Unequip(charID, slot)`
- 分解：`Decompose(charID, equipID)` → 计算经验+金币 → 调用 CharacterSvc + CurrencySvc
- 属性范围表：按品质查表随机生成属性

---

## Phase 4: 技能模块

**目标:** Gacha 抽取、技能仓库、槽位管理。

核心实现：
- 品质概率表：基于商店等级（1~28）查配置
- 冷却池：同品质 N 抽内不重复
- 4 个槽位：`SetSkillSlot(charID, slot(1-4), skillID)`
- 技能商店等级：`累计抽取次数 → level (300 * 1.25^(level-1))`

---

## Phase 5: 开箱模块

**目标:** 箱子管理、开箱（品质随机）、区域升级。

核心实现：
- `chest_inventory` 表：`chest_count` + `zone_level`
- 开箱：扣减 1 个箱子 → 按 `zone_level` 品质池随机 → 生成装备 → 写入仓库
- 区域升级：消耗金币 `1000 * 1.2^(level-1)`，最高 28 级

---

## Phase 6: 关卡模块

**目标:** 关卡配置加载、进度记录、解锁逻辑。

核心实现：
- `stages` 配置表或静态 JSON 文件
- 关卡配置结构：
```go
type StageConfig struct {
    StageID string      `json:"stage_id"`
    Chapter int         `json:"chapter"`
    Level   int         `json:"level"`
    Waves   []WaveConfig `json:"waves"`
}

type WaveConfig struct {
    IsBoss   bool          `json:"is_boss"`
    Monsters []MonsterConfig `json:"monsters"`
}

type MonsterConfig struct {
    Count int `json:"count"`
    HP    int `json:"hp"`
    ATK   int `json:"atk"`
    DEF   int `json:"def"`
}
```
- 进度：`stage_progress` 表 (chapter, level)
- 解锁规则：`current.chapter * 10 + current.level >= target.chapter * 10 + target.level - 1`

---

## Phase 7: 货币模块

**目标:** 金币/技能券原子增减 + 流水记录。

核心实现：
```go
func (s *CurrencyService) AddGold(charID int64, amount int64, reason string) error
func (s *CurrencyService) AddSkillTicket(charID int64, amount int64, reason string) error
```
- `SELECT ... FOR UPDATE` 行锁保证原子性
- 流水写入 `currency_logs` 表

---

## Phase 8: 战斗校验模块

**目标:** WebSocket 连接管理、方案 A 即时校验、方案 B Redis Streams 异步重跑。

核心实现：
- WebSocket Handler：连接认证 → 下发关卡配置 → 接收战斗摘要 → 方案A校验 → 入队方案B
- 方案A 校验维度（见 detailed-design §10.4）
- 方案B Worker：消费 Redis Stream → 简化战斗模拟 → 比对 HP 差异 < 5%
- 异常记录：`battle_anomalies` 表

---

## Phase 9: 排行榜模块

**目标:** Redis Sorted Set 分区排行榜。

核心实现：
- Key: `leaderboard:chapter:{n}`
- Score: `stage_progress.order_score`（`chapter * 1000 + level`）
- `ZADD` / `ZREVRANK` / `ZREVRANGE`

---

## Phase 10: 集成 & 路由注册

**目标:** 所有模块串联、依赖注入、完整路由注册。

核心实现：
- `cmd/server/main.go` 注入所有 Repo → Service → Handler
- 路由分组：`/api/auth/*`, `/api/character/*`, `/api/equipment/*`, `/api/skill/*`, `/api/chest/*`, `/api/stage/*`, `/api/leaderboard/*`
- WebSocket 独立路由：`/ws/battle`
- 端到端测试：注册 → 登录 → 查看角色 → 装备 → 开箱 → 抽技能 → 战斗结算

---

## Phase 11: Godot 客户端

**目标:** Godot 项目创建、所有 UI 场景、网络通信、战斗模拟。

客户端实施按 detailed-design §14 和 §15 执行，关键模块：
- Autoload 单例：`NetworkManager`, `PlayerState`, `EventBus`
- 场景：Login, Main, Battle, Equipment, Skill, Chest, Leaderboard
- 战斗模拟器：`BattleSimulator.gd`（每帧 tick，攻击 + 技能 + 波次切换）
- 数据模型：CharacterModel, EquipmentModel, SkillModel, StageModel

---

## Phase 12: 前后端联调

**目标:** 客户端 ↔ 服务端全流程跑通。

验证流程：
1. 客户端登录 → 服务端返回 Token
2. 客户端请求角色数据 → 服务端返回属性
3. 客户端操作装备/技能 → 服务端同步
4. 客户端开始战斗 → WebSocket 连接 → 上报摘要 → 方案A 即时返回 → 方案B 异步返回
5. 客户端查看排行榜 → 服务端返回排名

---

> 本文档基于设计文档 v1.0 编写，随开发进展按需迭代修改。
> 完整、详细的任务步骤（含具体代码）在实施每个 Phase 时按 TDD 流程展开。
