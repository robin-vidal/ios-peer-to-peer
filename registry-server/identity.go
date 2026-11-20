package main

import (
	"crypto/ecdh"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"math/big"
	"time"
)

const (
	authDomain   = "ios-registry-auth-v1"
	nonceLen     = 32
	challengeTTL = 30 * time.Second

	publicKeyLen = 65
	signatureLen = 64
)

var (
	errBadKey         = errors.New("bad-key")
	errBadSignature   = errors.New("bad-signature")
	errNoChallenge    = errors.New("no-challenge")
	errStaleChallenge = errors.New("stale-challenge")
)

type Identity struct {
	signPub    *ecdsa.PublicKey
	signPubRaw []byte
	boxPubRaw  []byte
}

func decodePublicKey(encoded string) ([]byte, error) {
	raw, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil || len(raw) != publicKeyLen {
		return nil, errBadKey
	}
	return raw, nil
}

func ParseIdentity(signPubB64, boxPubB64 string) (Identity, error) {
	signPubRaw, err := decodePublicKey(signPubB64)
	if err != nil {
		return Identity{}, err
	}
	signPub, err := ecdsa.ParseUncompressedPublicKey(elliptic.P256(), signPubRaw)
	if err != nil {
		return Identity{}, errBadKey
	}

	boxPubRaw, err := decodePublicKey(boxPubB64)
	if err != nil {
		return Identity{}, err
	}
	if _, err := ecdh.P256().NewPublicKey(boxPubRaw); err != nil {
		return Identity{}, errBadKey
	}

	return Identity{
		signPub:    signPub,
		signPubRaw: signPubRaw,
		boxPubRaw:  boxPubRaw,
	}, nil
}

func (i Identity) ID() string {
	sum := sha256.New()
	sum.Write(i.signPubRaw)
	sum.Write(i.boxPubRaw)
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
	if id.signPub == nil {
		return errBadKey
	}

	sig, err := base64.StdEncoding.DecodeString(sigB64)
	if err != nil || len(sig) != signatureLen {
		return errBadSignature
	}

	signed := make([]byte, 0, len(authDomain)+len(c.nonce))
	signed = append(signed, authDomain...)
	signed = append(signed, c.nonce...)
	digest := sha256.Sum256(signed)

	half := signatureLen / 2
	r := new(big.Int).SetBytes(sig[:half])
	s := new(big.Int).SetBytes(sig[half:])

	if !ecdsa.Verify(id.signPub, digest[:], r, s) {
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
		return reply("ERR usage HELLO <p256-sign-pub-b64> <p256-agree-pub-b64>")
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
