package service

import "testing"

func TestCurrencyTypeConstants(t *testing.T) {
	if CurrencyGold != "gold" {
		t.Errorf("CurrencyGold = %s", CurrencyGold)
	}
	if CurrencySkillTicket != "skill_ticket" {
		t.Errorf("CurrencySkillTicket = %s", CurrencySkillTicket)
	}
}

func TestNewCurrencyService(t *testing.T) {
	svc := NewCurrencyService(nil)
	if svc == nil {
		t.Error("NewCurrencyService returned nil")
	}
}
