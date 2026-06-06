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

func TestCurrencyLogStruct(t *testing.T) {
	log := CurrencyLog{CharacterID: 1, Currency: CurrencyGold, Amount: 100, Reason: "test"}
	if log.CharacterID != 1 || log.Amount != 100 {
		t.Error("CurrencyLog fields incorrect")
	}
}
