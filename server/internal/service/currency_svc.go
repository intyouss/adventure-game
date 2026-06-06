package service

import (
	"context"
	"fmt"

	"github.com/adventure-game/server/internal/repository"
)

// CurrencyType represents a currency kind.
type CurrencyType string

const (
	CurrencyGold        CurrencyType = "gold"
	CurrencySkillTicket CurrencyType = "skill_ticket"
)

type CurrencyService struct {
	charRepo *repository.CharacterRepo
}

func NewCurrencyService(charRepo *repository.CharacterRepo) *CurrencyService {
	return &CurrencyService{charRepo: charRepo}
}

// AddGold adds gold to a character and writes a currency log.
func (s *CurrencyService) AddGold(ctx context.Context, charID int64, amount int64, reason string) error {
	if amount <= 0 {
		return fmt.Errorf("amount must be positive")
	}
	char, err := s.charRepo.FindByID(ctx, charID)
	if err != nil || char == nil {
		return fmt.Errorf("character not found")
	}
	char.Gold += amount
	if err := s.charRepo.UpdateStats(ctx, char); err != nil {
		return err
	}
	_ = s.charRepo.InsertCurrencyLog(ctx, charID, "gold", amount, reason)
	return nil
}

// DeductGold deducts gold. Returns error if insufficient.
func (s *CurrencyService) DeductGold(ctx context.Context, charID int64, amount int64, reason string) error {
	if amount <= 0 {
		return fmt.Errorf("amount must be positive")
	}
	char, err := s.charRepo.FindByID(ctx, charID)
	if err != nil || char == nil {
		return fmt.Errorf("character not found")
	}
	if char.Gold < amount {
		return fmt.Errorf("insufficient gold")
	}
	char.Gold -= amount
	if err := s.charRepo.UpdateStats(ctx, char); err != nil {
		return err
	}
	_ = s.charRepo.InsertCurrencyLog(ctx, charID, "gold", -amount, reason)
	return nil
}

// AddSkillTickets adds skill tickets and writes a currency log.
func (s *CurrencyService) AddSkillTickets(ctx context.Context, charID int64, amount int64, reason string) error {
	if amount <= 0 {
		return fmt.Errorf("amount must be positive")
	}
	char, err := s.charRepo.FindByID(ctx, charID)
	if err != nil || char == nil {
		return fmt.Errorf("character not found")
	}
	char.SkillTickets += amount
	if err := s.charRepo.UpdateStats(ctx, char); err != nil {
		return err
	}
	_ = s.charRepo.InsertCurrencyLog(ctx, charID, "skill_ticket", amount, reason)
	return nil
}
