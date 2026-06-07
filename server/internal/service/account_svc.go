package service

import (
	"context"
	"crypto/rand"
	"database/sql"
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
	repo      *repository.AccountRepo
	charRepo  *repository.CharacterRepo
	redis     *redis.Client
	jwtCfg    config.JWTConfig
	verifyCfg config.VerifyConfig
}

func NewAccountService(repo *repository.AccountRepo, charRepo *repository.CharacterRepo, rdb *redis.Client, jwtCfg config.JWTConfig, verifyCfg config.VerifyConfig) *AccountService {
	return &AccountService{repo: repo, charRepo: charRepo, redis: rdb, jwtCfg: jwtCfg, verifyCfg: verifyCfg}
}

func (s *AccountService) SendVerificationCode(ctx context.Context, target string) error {
	cooldownKey := "verify_cooldown:" + target
	exists, err := s.redis.Exists(ctx, cooldownKey).Result()
	if err != nil {
		return fmt.Errorf("check cooldown: %w", err)
	}
	if exists > 0 {
		return fmt.Errorf("send code too frequent")
	}

	code, err := generateCode()
	if err != nil {
		return fmt.Errorf("generate code: %w", err)
	}

	data := map[string]interface{}{"code": code, "attempts": 0}
	jsonData, _ := json.Marshal(data)
	codeKey := "verify_code:" + target
	if err := s.redis.Set(ctx, codeKey, jsonData, 5*time.Minute).Err(); err != nil {
		return fmt.Errorf("store code: %w", err)
	}

	if err := s.redis.Set(ctx, cooldownKey, "1", 60*time.Second).Err(); err != nil {
		return fmt.Errorf("set cooldown: %w", err)
	}

	return nil
}

func (s *AccountService) VerifyCode(ctx context.Context, target, code string) error {
	if s.verifyCfg.TestCode != "" && code == s.verifyCfg.TestCode {
		return nil
	}

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

	s.redis.Del(ctx, codeKey)
	s.redis.Del(ctx, "verify_cooldown:"+target)
	return nil
}

type RegisterRequest struct {
	Phone    string `json:"phone"`
	Email    string `json:"email"`
	Password string `json:"password" binding:"required"`
	Code     string `json:"code" binding:"required"`
	Nickname string `json:"nickname"`
}

type LoginRequest struct {
	Account  string `json:"account" binding:"required"`
	Password string `json:"password"`
	Code     string `json:"code"`
}

type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"`
	AccountID    int64  `json:"account_id"`
	CharacterID  int64  `json:"character_id"`
}

func (s *AccountService) Register(ctx context.Context, req RegisterRequest) (*TokenPair, error) {
	target := req.Phone
	targetType := "phone"
	if target == "" {
		target = req.Email
		targetType = "email"
	}
	if target == "" {
		return nil, fmt.Errorf("phone/email required")
	}

	if err := s.VerifyCode(ctx, target, req.Code); err != nil {
		return nil, err
	}

	var existing *model.Account
	var err error
	if targetType == "phone" {
		existing, err = s.repo.FindByPhone(ctx, target)
	} else {
		existing, err = s.repo.FindByEmail(ctx, target)
	}
	if err != nil {
		return nil, fmt.Errorf("check existing: %w", err)
	}
	if existing != nil {
		return nil, fmt.Errorf("already registered")
	}

	hash, err := password.Hash(req.Password)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}

	account := &model.Account{PasswordHash: hash}
	if targetType == "phone" {
		account.Phone = sql.NullString{String: target, Valid: true}
	} else {
		account.Email = sql.NullString{String: target, Valid: true}
	}
	if err := s.repo.Create(ctx, account); err != nil {
		return nil, fmt.Errorf("create account: %w", err)
	}

	nickname := req.Nickname
	if nickname == "" {
		nickname = fmt.Sprintf("冒险家%06d", account.ID)
	}
	char := &model.Character{
		AccountID:    account.ID,
		Class:        "warrior",
		Nickname:     nickname,
		Level:        1,
		Exp:          0,
		Gold:         0,
		StageChapter: 1,
		StageLevel:   1,
	}
	if err := s.charRepo.Create(ctx, char); err != nil {
		return nil, fmt.Errorf("create character: %w", err)
	}

	return s.generateTokens(account.ID, char.ID)
}

func (s *AccountService) Login(ctx context.Context, req LoginRequest) (*TokenPair, error) {
	account, err := s.repo.FindByPhone(ctx, req.Account)
	if err != nil {
		return nil, fmt.Errorf("find account: %w", err)
	}
	if account == nil {
		account, err = s.repo.FindByEmail(ctx, req.Account)
		if err != nil {
			return nil, fmt.Errorf("find account: %w", err)
		}
	}
	if account == nil {
		return nil, fmt.Errorf("account not found")
	}

	if req.Password != "" {
		// Branch 3: Account + Password login
		if !password.Verify(req.Password, account.PasswordHash) {
			return nil, fmt.Errorf("wrong password")
		}
	} else if req.Code != "" {
		// Branch 1 & 2: Phone/Email + Verification Code login
		// First: check if code matches stored quick_code (shared input param)
		if !(account.QuickCode.Valid && req.Code == account.QuickCode.String) {
			// Verify as verification code via Redis
			target := account.PhoneStr()
			if target == "" {
				target = account.EmailStr()
			}
			if err := s.VerifyCode(ctx, target, req.Code); err != nil {
				return nil, err
			}
		}
	} else {
		return nil, fmt.Errorf("password or code required")
	}

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

	s.redis.Del(ctx, key)

	return s.generateTokens(data.AccountID, data.CharacterID)
}

func (s *AccountService) generateTokens(accountID, characterID int64) (*TokenPair, error) {
	accessToken, err := jwt.Generate(s.jwtCfg.Secret, accountID, characterID, s.jwtCfg.AccessTTL)
	if err != nil {
		return nil, fmt.Errorf("generate access token: %w", err)
	}

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
		AccountID:    accountID,
		CharacterID:  characterID,
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
