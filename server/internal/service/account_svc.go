package service

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"math/big"
	"time"

	"github.com/redis/go-redis/v9"

	"github.com/adventure-game/server/config"
	"github.com/adventure-game/server/internal/model"
	"github.com/adventure-game/server/internal/repository"
	"github.com/adventure-game/server/pkg/jwt"
	"github.com/adventure-game/server/pkg/password"
)

type AccountService struct {
	repo     *repository.AccountRepo
	charRepo *repository.CharacterRepo
	redis    *redis.Client
	jwtCfg   config.JWTConfig
}

func NewAccountService(repo *repository.AccountRepo, charRepo *repository.CharacterRepo, rdb *redis.Client, jwtCfg config.JWTConfig) *AccountService {
	return &AccountService{repo: repo, charRepo: charRepo, redis: rdb, jwtCfg: jwtCfg}
}

// SendVerificationCode generates a 6-digit code, stores in Redis with 5-min TTL.
func (s *AccountService) SendVerificationCode(ctx context.Context, target string) error {
	// Rate limit: 60s cooldown
	cooldownKey := "verify_cooldown:" + target
	exists, err := s.redis.Exists(ctx, cooldownKey).Result()
	if err != nil {
		return fmt.Errorf("check cooldown: %w", err)
	}
	if exists > 0 {
		return fmt.Errorf("send code too frequent")
	}

	// Generate 6-digit code
	code, err := generateCode()
	if err != nil {
		return fmt.Errorf("generate code: %w", err)
	}

	// Store in Redis: 5 min TTL
	data := map[string]interface{}{"code": code, "attempts": 0}
	jsonData, _ := json.Marshal(data)
	codeKey := "verify_code:" + target
	if err := s.redis.Set(ctx, codeKey, jsonData, 5*time.Minute).Err(); err != nil {
		return fmt.Errorf("store code: %w", err)
	}

	// Set cooldown: 60s
	if err := s.redis.Set(ctx, cooldownKey, "1", 60*time.Second).Err(); err != nil {
		return fmt.Errorf("set cooldown: %w", err)
	}

	return nil
}

// VerifyCode validates a verification code. Returns nil if valid, error otherwise.
func (s *AccountService) VerifyCode(ctx context.Context, target, code string) error {
	codeKey := "verify_code:" + target
	raw, err := s.redis.Get(ctx, codeKey).Result()
	if err == redis.Nil {
		return fmt.Errorf("invalid or expired code")
	}
	if err != nil {
		return fmt.Errorf("get code: %w", err)
	}

	var data struct {
		Code     string `json:"code"`
		Attempts int    `json:"attempts"`
	}
	if err := json.Unmarshal([]byte(raw), &data); err != nil {
		return fmt.Errorf("parse code data: %w", err)
	}

	if data.Attempts >= 5 {
		s.redis.Del(ctx, codeKey)
		return fmt.Errorf("too many attempts")
	}

	data.Attempts++
	jsonData, _ := json.Marshal(data)
	s.redis.Set(ctx, codeKey, jsonData, s.redis.PTTL(ctx, codeKey).Val())

	if data.Code != code {
		return fmt.Errorf("wrong code")
	}

	// Code valid — delete from Redis
	s.redis.Del(ctx, codeKey)
	s.redis.Del(ctx, "verify_cooldown:"+target)
	return nil
}

// RegisterRequest represents a registration request.
type RegisterRequest struct {
	Target   string `json:"target"`   // phone or email
	Type     string `json:"type"`     // "phone" or "email"
	Code     string `json:"code"`
	Password string `json:"password"`
}

// LoginRequest represents a login request.
type LoginRequest struct {
	Target   string `json:"target"`
	Password string `json:"password"`
}

// TokenPair contains an access token and refresh token.
type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"`
}

// Register handles new user registration.
func (s *AccountService) Register(ctx context.Context, req RegisterRequest) (*TokenPair, error) {
	// Validate target
	if req.Target == "" || (req.Type != "phone" && req.Type != "email") {
		return nil, fmt.Errorf("invalid target")
	}

	// Verify code
	if err := s.VerifyCode(ctx, req.Target, req.Code); err != nil {
		return nil, err
	}

	// Check existing
	var existing *model.Account
	var err error
	if req.Type == "phone" {
		existing, err = s.repo.FindByPhone(ctx, req.Target)
	} else {
		existing, err = s.repo.FindByEmail(ctx, req.Target)
	}
	if err != nil {
		return nil, fmt.Errorf("check existing: %w", err)
	}
	if existing != nil {
		return nil, fmt.Errorf("already registered")
	}

	// Hash password
	hash, err := password.Hash(req.Password)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}

	// Create account
	account := &model.Account{PasswordHash: hash}
	if req.Type == "phone" {
		account.Phone = req.Target
	} else {
		account.Email = req.Target
	}
	if err := s.repo.Create(ctx, account); err != nil {
		return nil, fmt.Errorf("create account: %w", err)
	}

	// Auto-create character for the new account
	char := &model.Character{
		AccountID:    account.ID,
		Class:        "warrior",
		Nickname:     "",
		Level:        1,
		Exp:          0,
		Gold:         0,
		StageChapter: 1,
		StageLevel:   1,
	}
	if err := s.charRepo.Create(ctx, char); err != nil {
		return nil, fmt.Errorf("create character: %w", err)
	}

	// Generate tokens with real character ID
	return s.generateTokens(account.ID, char.ID)
}

// Login authenticates a user and returns tokens.
func (s *AccountService) Login(ctx context.Context, req LoginRequest) (*TokenPair, error) {
	// Find account by phone or email
	account, err := s.repo.FindByPhone(ctx, req.Target)
	if err != nil {
		return nil, fmt.Errorf("find account: %w", err)
	}
	if account == nil {
		account, err = s.repo.FindByEmail(ctx, req.Target)
		if err != nil {
			return nil, fmt.Errorf("find account: %w", err)
		}
	}
	if account == nil {
		return nil, fmt.Errorf("account not found")
	}

	// Verify password
	if !password.Verify(req.Password, account.PasswordHash) {
		return nil, fmt.Errorf("wrong password")
	}

	// Look up character for this account
	char, err := s.charRepo.FindByAccountID(ctx, account.ID)
	if err != nil {
		return nil, fmt.Errorf("find character: %w", err)
	}
	charID := int64(0)
	if char != nil {
		charID = char.ID
	}

	return s.generateTokens(account.ID, charID)
}

// RefreshAccessToken generates a new access token from a valid refresh token.
func (s *AccountService) RefreshAccessToken(ctx context.Context, refreshToken string) (*TokenPair, error) {
	key := "refresh_token:" + refreshToken
	raw, err := s.redis.Get(ctx, key).Result()
	if err == redis.Nil {
		return nil, fmt.Errorf("invalid refresh token")
	}
	if err != nil {
		return nil, fmt.Errorf("get refresh token: %w", err)
	}

	var data struct {
		AccountID   int64 `json:"account_id"`
		CharacterID int64 `json:"character_id"`
	}
	if err := json.Unmarshal([]byte(raw), &data); err != nil {
		return nil, fmt.Errorf("parse token data: %w", err)
	}

	// Delete old refresh token (rotation)
	s.redis.Del(ctx, key)

	return s.generateTokens(data.AccountID, data.CharacterID)
}

func (s *AccountService) generateTokens(accountID, characterID int64) (*TokenPair, error) {
	accessToken, err := jwt.Generate(s.jwtCfg.Secret, accountID, characterID, s.jwtCfg.AccessTTL)
	if err != nil {
		return nil, fmt.Errorf("generate access token: %w", err)
	}

	// Generate refresh token (UUID stored in Redis)
	refreshToken, err := generateUUID()
	if err != nil {
		return nil, fmt.Errorf("generate refresh token: %w", err)
	}

	data := map[string]interface{}{
		"account_id":   accountID,
		"character_id": characterID,
	}
	jsonData, _ := json.Marshal(data)
	if err := s.redis.Set(context.Background(), "refresh_token:"+refreshToken, jsonData, 7*24*time.Hour).Err(); err != nil {
		return nil, fmt.Errorf("store refresh token: %w", err)
	}

	return &TokenPair{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    s.jwtCfg.AccessTTL,
	}, nil
}

func generateCode() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

func generateUUID() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return fmt.Sprintf("%08x-%04x-%04x-%04x-%012x",
		b[0:4], b[4:6], b[6:8], b[8:10], b[10:16]), nil
}
