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

func TestHashDifferentSalts(t *testing.T) {
	pw := "test"
	h1, _ := Hash(pw)
	h2, _ := Hash(pw)
	if h1 == h2 {
		t.Fatal("Hash() should produce different salts for each call")
	}
}

func TestVerifyInvalidFormat(t *testing.T) {
	if Verify("password", "not-a-valid-hash") {
		t.Fatal("Verify() should return false for invalid hash format")
	}
}
