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
	"testing"
	"time"
)

type testIdentity struct {
	signKey    *ecdsa.PrivateKey
	signPubRaw []byte
	boxPubRaw  []byte
}

func newTestIdentity(t *testing.T) testIdentity {
	t.Helper()

	signKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("unable to generate a signing key: %v", err)
	}
	signPubRaw, err := signKey.PublicKey.Bytes()
	if err != nil {
		t.Fatalf("unable to encode a signing key: %v", err)
	}

	boxKey, err := ecdh.P256().GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("unable to generate an agreement key: %v", err)
	}

	return testIdentity{
		signKey:    signKey,
		signPubRaw: signPubRaw,
		boxPubRaw:  boxKey.PublicKey().Bytes(),
	}
}

func (ti testIdentity) encoded() (string, string) {
	return base64.StdEncoding.EncodeToString(ti.signPubRaw),
		base64.StdEncoding.EncodeToString(ti.boxPubRaw)
}

func (ti testIdentity) parse(t *testing.T) Identity {
	t.Helper()

	signPubB64, boxPubB64 := ti.encoded()
	ident, err := ParseIdentity(signPubB64, boxPubB64)
	if err != nil {
		t.Fatalf("unable to parse a freshly generated identity: %v", err)
	}
	return ident
}

func (ti testIdentity) sign(t *testing.T, nonce []byte) string {
	t.Helper()

	signed := make([]byte, 0, len(authDomain)+len(nonce))
	signed = append(signed, authDomain...)
	signed = append(signed, nonce...)
	digest := sha256.Sum256(signed)

	r, s, err := ecdsa.Sign(rand.Reader, ti.signKey, digest[:])
	if err != nil {
		t.Fatalf("unable to sign a challenge: %v", err)
	}

	sig := make([]byte, signatureLen)
	half := signatureLen / 2
	r.FillBytes(sig[:half])
	s.FillBytes(sig[half:])
	return base64.StdEncoding.EncodeToString(sig)
}

func freshChallenge(t *testing.T) Challenge {
	t.Helper()

	chal, err := NewChallenge()
	if err != nil {
		t.Fatalf("unable to create a challenge: %v", err)
	}
	if len(chal.nonce) != nonceLen {
		t.Fatalf("nonce is %d bytes, want %d", len(chal.nonce), nonceLen)
	}
	return chal
}

func TestParseIdentityAcceptsP256Keys(t *testing.T) {
	ti := newTestIdentity(t)

	if len(ti.signPubRaw) != publicKeyLen {
		t.Fatalf("signing key is %d bytes, want %d", len(ti.signPubRaw), publicKeyLen)
	}
	if len(ti.boxPubRaw) != publicKeyLen {
		t.Fatalf("agreement key is %d bytes, want %d", len(ti.boxPubRaw), publicKeyLen)
	}

	ident := ti.parse(t)
	if ident.signPub == nil {
		t.Fatal("parsed identity holds no signing key")
	}
}

func TestParseIdentityRejectsBadKeys(t *testing.T) {
	ti := newTestIdentity(t)
	signPubB64, boxPubB64 := ti.encoded()

	offCurve := make([]byte, publicKeyLen)
	copy(offCurve, ti.signPubRaw)
	offCurve[publicKeyLen-1] ^= 0x01
	offCurveB64 := base64.StdEncoding.EncodeToString(offCurve)

	compressed := base64.StdEncoding.EncodeToString(ti.signPubRaw[:33])
	padded := base64.StdEncoding.EncodeToString(append(ti.signPubRaw, 0x00))

	cases := []struct {
		name    string
		signPub string
		boxPub  string
	}{
		{"empty signing key", "", boxPubB64},
		{"empty agreement key", signPubB64, ""},
		{"signing key not base64", "not base64!!", boxPubB64},
		{"agreement key not base64", signPubB64, "not base64!!"},
		{"signing key too short", compressed, boxPubB64},
		{"signing key too long", padded, boxPubB64},
		{"agreement key too short", signPubB64, compressed},
		{"signing key off curve", offCurveB64, boxPubB64},
		{"agreement key off curve", signPubB64, offCurveB64},
		{"keys swapped for nothing", offCurveB64, offCurveB64},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if _, err := ParseIdentity(tc.signPub, tc.boxPub); !errors.Is(err, errBadKey) {
				t.Fatalf("got error %v, want %v", err, errBadKey)
			}
		})
	}
}

func TestIDHashesBothPublicKeys(t *testing.T) {
	ti := newTestIdentity(t)
	ident := ti.parse(t)

	sum := sha256.New()
	sum.Write(ti.signPubRaw)
	sum.Write(ti.boxPubRaw)
	want := hex.EncodeToString(sum.Sum(nil))

	if got := ident.ID(); got != want {
		t.Fatalf("id is %s, want %s", got, want)
	}
	if !ValidID(ident.ID()) {
		t.Fatalf("id %s is not accepted by ValidID", ident.ID())
	}
}

func TestIDDependsOnEveryKey(t *testing.T) {
	first := newTestIdentity(t)
	second := newTestIdentity(t)

	firstSign, firstBox := first.encoded()
	secondSign, secondBox := second.encoded()

	base, err := ParseIdentity(firstSign, firstBox)
	if err != nil {
		t.Fatalf("unable to parse the base identity: %v", err)
	}

	otherSign, err := ParseIdentity(secondSign, firstBox)
	if err != nil {
		t.Fatalf("unable to parse a mixed identity: %v", err)
	}
	otherBox, err := ParseIdentity(firstSign, secondBox)
	if err != nil {
		t.Fatalf("unable to parse a mixed identity: %v", err)
	}

	if base.ID() == otherSign.ID() {
		t.Fatal("a different signing key produced the same id")
	}
	if base.ID() == otherBox.ID() {
		t.Fatal("a different agreement key produced the same id")
	}
}

func TestChallengeVerifyAcceptsAGoodSignature(t *testing.T) {
	ti := newTestIdentity(t)
	ident := ti.parse(t)
	chal := freshChallenge(t)

	if err := chal.Verify(ident, ti.sign(t, chal.nonce), time.Now()); err != nil {
		t.Fatalf("a valid signature was refused: %v", err)
	}
}

func TestChallengeVerifyRejectsBadSignatures(t *testing.T) {
	ti := newTestIdentity(t)
	ident := ti.parse(t)
	other := newTestIdentity(t)

	chal := freshChallenge(t)
	good := ti.sign(t, chal.nonce)

	raw, err := base64.StdEncoding.DecodeString(good)
	if err != nil {
		t.Fatalf("unable to decode a signature we just made: %v", err)
	}
	tampered := make([]byte, len(raw))
	copy(tampered, raw)
	tampered[0] ^= 0x01

	zeroed := base64.StdEncoding.EncodeToString(make([]byte, signatureLen))

	cases := []struct {
		name string
		sig  string
		want error
	}{
		{"not base64", "not base64!!", errBadSignature},
		{"empty", "", errBadSignature},
		{"too short", base64.StdEncoding.EncodeToString(raw[:signatureLen-1]), errBadSignature},
		{"too long", base64.StdEncoding.EncodeToString(append(raw, 0x00)), errBadSignature},
		{"tampered", base64.StdEncoding.EncodeToString(tampered), errBadSignature},
		{"r and s zero", zeroed, errBadSignature},
		{"signed by another key", other.sign(t, chal.nonce), errBadSignature},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if err := chal.Verify(ident, tc.sig, time.Now()); !errors.Is(err, tc.want) {
				t.Fatalf("got error %v, want %v", err, tc.want)
			}
		})
	}
}

func TestChallengeVerifyRejectsAnotherNonce(t *testing.T) {
	ti := newTestIdentity(t)
	ident := ti.parse(t)

	chal := freshChallenge(t)
	stranger := freshChallenge(t)

	if err := chal.Verify(ident, ti.sign(t, stranger.nonce), time.Now()); !errors.Is(err, errBadSignature) {
		t.Fatalf("a signature over another nonce was accepted")
	}
}

func TestChallengeVerifyRejectsMissingAndStaleChallenges(t *testing.T) {
	ti := newTestIdentity(t)
	ident := ti.parse(t)
	chal := freshChallenge(t)
	good := ti.sign(t, chal.nonce)

	if err := (Challenge{}).Verify(ident, good, time.Now()); !errors.Is(err, errNoChallenge) {
		t.Fatalf("an absent challenge was not reported")
	}

	late := chal.issued.Add(challengeTTL + time.Second)
	if err := chal.Verify(ident, good, late); !errors.Is(err, errStaleChallenge) {
		t.Fatalf("an expired challenge was not reported")
	}
}

func TestChallengeVerifyRejectsAnEmptyIdentity(t *testing.T) {
	ti := newTestIdentity(t)
	chal := freshChallenge(t)

	if err := chal.Verify(Identity{}, ti.sign(t, chal.nonce), time.Now()); !errors.Is(err, errBadKey) {
		t.Fatalf("an identity with no key was accepted")
	}
}
