package jwt

import (
	"testing"
)

func TestGenerateAndParse(t *testing.T) {
	secret := "test-secret-key-at-least-32-chars!!"
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
	secret := "test-secret-key-at-least-32-chars!!"
	token, err := Generate(secret, 1, 1, -1)
	if err != nil {
		t.Fatalf("Generate() error = %v", err)
	}
	_, err = Parse(secret, token)
	if err == nil {
		t.Fatal("Parse() should fail for expired token")
	}
}

func TestWrongSecret(t *testing.T) {
	token, err := Generate("secret-a-key-thats-long-enough", 1, 1, 3600)
	if err != nil {
		t.Fatalf("Generate() error = %v", err)
	}
	_, err = Parse("secret-b-key-thats-long-enough", token)
	if err == nil {
		t.Fatal("Parse() should fail with wrong secret")
	}
}

func TestInvalidToken(t *testing.T) {
	_, err := Parse("some-secret-key-thats-long-enough", "not-a-valid-jwt-token")
	if err == nil {
		t.Fatal("Parse() should fail for invalid token string")
	}
}
