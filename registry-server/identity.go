package main

import (
	"crypto/ecdh"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"time"
)

const (
	authDomain   = "ios-registry-auth-v1"
	nonceLen     = 32
	challengeTTL = 30 * time.Second
)

var (
	errBadKey         = errors.New("bad-key")
	errBadSignature   = errors.New("bad-signature")
	errNoChallenge    = errors.New("no-challenge")
	errStaleChallenge = errors.New("stale-challenge")
)

type Identity struct {
	signPub ed25519.PublicKey
	boxPub  []byte
}

func ParseIdentity(signPubB64, boxPubB64 string) (Identity, error) {
	signPub, err := base64.StdEncoding.DecodeString(signPubB64)
	if err != nil || len(signPub) != ed25519.PublicKeySize {
		return Identity{}, errBadKey
	}

	boxPub, err := base64.StdEncoding.DecodeString(boxPubB64)
	if err != nil {
		return Identity{}, errBadKey
	}
	if _, err := ecdh.X25519().NewPublicKey(boxPub); err != nil {
		return Identity{}, errBadKey
	}

	return Identity{signPub: ed25519.PublicKey(signPub), boxPub: boxPub}, nil
}

func (i Identity) ID() string {
	sum := sha256.New()
	sum.Write(i.signPub)
	sum.Write(i.boxPub)
	return hex.EncodeToString(sum.Sum(nil))
}

type Challenge struct {
	nonce  []byte
	issued time.Time
}

func NewChallenge() (Challenge, error) {
	nonce := make([]byte, nonceLen)
	if _, err := rand.Read(nonce); err != nil {
		return Challenge{}, err
	}
	return Challenge{nonce: nonce, issued: time.Now()}, nil
}

func (c Challenge) Encode() string {
	return base64.StdEncoding.EncodeToString(c.nonce)
}

func (c Challenge) Verify(id Identity, sigB64 string, now time.Time) error {
	if len(c.nonce) == 0 {
		return errNoChallenge
	}
	if now.Sub(c.issued) > challengeTTL {
		return errStaleChallenge
	}
	if len(id.signPub) != ed25519.PublicKeySize {
		return errBadKey
	}

	sig, err := base64.StdEncoding.DecodeString(sigB64)
	if err != nil || len(sig) != ed25519.SignatureSize {
		return errBadSignature
	}

	signed := make([]byte, 0, len(authDomain)+len(c.nonce))
	signed = append(signed, authDomain...)
	signed = append(signed, c.nonce...)

	if !ed25519.Verify(id.signPub, signed, sig) {
		return errBadSignature
	}
	return nil
}

type handshake struct {
	ident  Identity
	chal   Challenge
	authed bool
	id     string
}

func (h *handshake) hello(reply replyFunc, fields []string) error {
	if h.authed {
		return reply("ERR already-authenticated")
	}
	if len(fields) != 3 {
		return reply("ERR usage HELLO <ed25519-pub-b64> <x25519-pub-b64>")
	}

	ident, err := ParseIdentity(fields[1], fields[2])
	if err != nil {
		h.ident, h.chal = Identity{}, Challenge{}
		return reply("ERR %s", err)
	}

	chal, err := NewChallenge()
	if err != nil {
		h.ident, h.chal = Identity{}, Challenge{}
		return reply("ERR internal")
	}

	h.ident, h.chal = ident, chal
	return reply("CHALLENGE %s", chal.Encode())
}

func (h *handshake) auth(reply replyFunc, fields []string) error {
	if h.authed {
		return reply("ERR already-authenticated")
	}
	if len(fields) != 2 {
		return reply("ERR usage AUTH <sig-b64>")
	}

	chal := h.chal
	h.chal = Challenge{}

	if err := chal.Verify(h.ident, fields[1], time.Now()); err != nil {
		return reply("ERR %s", err)
	}

	h.authed = true
	h.id = h.ident.ID()
	return reply("OK %s", h.id)
}
