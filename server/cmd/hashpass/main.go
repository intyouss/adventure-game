package main

import (
	"os"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"golang.org/x/crypto/argon2"
)

func main() {
	pwd := "111111"
	if len(os.Args) > 1 {
		pwd = os.Args[1]
	}
	salt := make([]byte, 16)
	rand.Read(salt)
	hash := argon2.IDKey([]byte(pwd), salt, 3, 64*1024, 4, 32)
	fmt.Printf("$argon2id$v=19$m=65536,t=3,p=4$%s$%s\n",
		base64.RawStdEncoding.EncodeToString(salt),
		base64.RawStdEncoding.EncodeToString(hash))
}
