# Peer session keys

Two peers that have each other's contact card open a session before any chat traffic. The session proves to each side that the other holds the signing key named by its card, and derives keys that no long term key can reconstruct afterwards.

For framing see [frames.md](frames.md), for what travels once the session is open see [chat.md](chat.md), for how the address was found see [protocol.md](protocol.md).

## Why a handshake above TLS

The peer connection already runs TLS, and TLS 1.3 is itself forward secret. It is not sufficient here for two reasons.

A TLS certificate key lives in the process. The identity key does not: it is generated in the Secure Enclave and signs without ever being readable, so it cannot be handed to a TLS stack as a certificate key. A peer therefore presents a self signed certificate under a software key, and the other end has nothing to pin it against: a contact card carries an identity key, not a certificate. The peer TLS layer is encryption without authentication, and this handshake is what names the peer, in band, where the enclave can produce the proof.

That ordering is deliberate rather than tolerated. A man in the middle who terminates both TLS connections and relays the handshake frames unchanged still never derives the session keys, since those come from the two peers' ephemerals and it holds neither private half. It relays bytes it cannot open, and the moment it edits one the tag fails. What it can do is forge a `keepalive`, which lies about liveness and carries nothing, and cut the connection, which it could do anyway.

The second reason is the message layer. A per message key is sealed to the recipient's long term agreement key, so a recipient's agreement key recovered later opens every message it ever received. Sealing the frame payloads under keys derived from two ephemerals removes that: once the session ends and both ephemerals are gone, the recorded bytes are not openable by any surviving key.

The long term agreement key from the contact card is not used in this handshake at all. It keeps the two jobs it already had: sealing address blobs in [protocol.md](protocol.md), and wrapping the per message key in [chat.md](chat.md).

## Identities and encodings

| Name | Size | Encoding |
|---|---|---|
| identity id | 32 | raw SHA-256 of both long term public keys, not its hex text |
| long term signing key | 65 | P-256 public key, x963 uncompressed, leading `0x04` |
| ephemeral key | 65 | P-256 public key, x963 uncompressed, leading `0x04` |
| signature | 64 | ECDSA P-256, `r` then `s`, 32 bytes each, big endian, never DER |
| confirmation | 32 | output of the key schedule below |
| counter | 8 | uint64 big endian |

`field(x)` is the length prefixed form used everywhere else: `uint32` big endian length, then the bytes. Integers are big endian.

The two roles are **dialer**, the peer that connected to an address it fetched, and **listener**, the peer that accepted the connection. They are fixed for the life of the session and they are not symmetric: the dialer speaks first and confirms last.

## Steps

Each step is the payload of one `handshake` frame, type `0x01`.

```
step 1, dialer   = field(id_dialer)  || field(eph_dialer)   || field(sig_dialer)      173 bytes
step 2, listener = field(eph_listener) || field(sig_listener) || field(confirm_l)     173 bytes
step 3, dialer   = field(confirm_d)                                                   36 bytes
```

```
sig_dialer   = ECDSA-P256-Sign(signing key of the dialer,   SHA-256(hello))
sig_listener = ECDSA-P256-Sign(signing key of the listener, SHA-256(reply))

hello = "ios-session-hello-v1"
     || field(id_dialer)        32
     || field(id_listener)      32
     || field(eph_dialer)       65

reply = "ios-session-reply-v1"
     || field(id_dialer)        32
     || field(id_listener)      32
     || field(eph_dialer)       65
     || field(eph_listener)     65
```

The domain prefixes are the literal ASCII bytes, 20 each, with no terminator and no length prefix of their own. They differ between the two signatures so that a recorded step 1 cannot be presented as a step 2.

`id_listener` is inside `hello` although step 1 does not transmit it: the dialer knows which contact it dialed, and the listener knows its own id. Signing it binds the handshake to one recipient, so a hello recorded by one contact cannot be forwarded to another.

Step 1 transmits `id_dialer` because the listener needs it to find the right contact card before it can verify anything. No other step repeats an identity.

## Key schedule

```
Z          = ECDH-P256(own ephemeral private, peer ephemeral public)    32 bytes, x coordinate only
transcript = "ios-session-v1"
          || field(id_dialer)        32
          || field(id_listener)      32
          || field(eph_dialer)       65
          || field(eph_listener)     65
TS         = SHA-256(transcript)                                        32 bytes
PRK        = HKDF-SHA256-Extract(salt = TS, ikm = Z)                    32 bytes

k_d2l      = HKDF-SHA256-Expand(PRK, "ios-session-v1 d2l", 32)
k_l2d      = HKDF-SHA256-Expand(PRK, "ios-session-v1 l2d", 32)
confirm_d  = HKDF-SHA256-Expand(PRK, "ios-session-v1 confirm d", 32)
confirm_l  = HKDF-SHA256-Expand(PRK, "ios-session-v1 confirm l", 32)
session_id = HKDF-SHA256-Expand(PRK, "ios-session-v1 id", 16)
```

`Z` is the x coordinate alone, 32 bytes, left padded if shorter. The full point is never hashed, so an implementation that hands back a compressed or uncompressed point must take the coordinate out of it first.

Both ephemeral public keys and both identity ids are inside `TS`, which is the HKDF salt. Two sessions therefore share a key only if both peers reused an ephemeral, and a key from one pair of contacts is never a key for another pair even if `Z` repeated.

The direction labels mean the keys are not shared between the two directions, so neither peer can replay the other's sealed frame back at it, and a GCM nonce is never used twice under one key.

## Confirmation and replay

Step 2 carries `confirm_l` and step 3 carries `confirm_d`. Each side compares the received value against the one it derived, in constant time, and closes on a mismatch.

This is what refuses a replayed handshake. A recorded step 1 verifies forever: its signature covers only the dialer's own ephemeral and the two ids, none of which go stale. What the replayer does not have is the private half of `eph_dialer`, so it cannot derive `PRK` against the listener's fresh ephemeral and cannot produce `confirm_d`. The handshake dies at step 3.

Freshness here comes from the responder's ephemeral and from the mandatory confirmation, never from a signature check. An implementation that accepts a session after step 2, or that treats a valid signature as evidence of liveness, is replayable.

A recorded step 2 is bound to both ephemerals through `reply`, so it is already useless against a dialer that generated a new one.

No nonce or timestamp is added. A timestamp would need clocks the rest of this design refuses to trust, and a nonce would carry the freshness the ephemeral already carries.

## Refusals

Each side closes the connection, without a reply, when:

- an ephemeral key is not 65 bytes, does not begin with `0x04`, or is not a point on P-256
- an ephemeral key equals either long term public key of either peer, which would destroy forward secrecy
- an ephemeral key equals the one the side generated for this session
- `id_dialer` in step 1 is not a known contact
- a signature does not verify under the signing key in that contact's card
- the id derived from the card's keys is not the id the step claims, or not the contact the dialer dialed
- a confirmation does not match the derived value
- a step arrives out of order, or a second step 1 arrives on an open connection
- the three steps do not complete within 5 seconds
- a session with the same peer is already open

A failed handshake leaves nothing behind: the ephemeral private key, `PRK` and every derived key are wiped, and no partially authenticated state is kept. There is no retry inside the connection. The dialer closes it and starts a new one, which generates a new ephemeral.

Refusals are silent for the reason given in [frames.md](frames.md): a reply from a parser reachable before authentication tells a prober which check it tripped.

## Sealed payloads

Once step 3 is verified, the payload of every `message` and `ack` frame is sealed:

```
payload = AES-GCM(k_dir, nonce, field(signed) || field(sig))     plaintext + 16 bytes
nonce   = 0x00000000 || counter          12 bytes, counter uint64 big endian
aad     = the 8 header bytes of this frame, version || type || reserved || length
```

`k_dir` is `k_d2l` for frames the dialer sends and `k_l2d` for frames the listener sends. Each direction keeps its own counter, starting at 0 and incremented by one per sealed frame. A receiver keeps the counter it expects next and never lowers it, so a replayed frame is opened under a nonce it was not sealed with and fails the tag.

The header is the AAD, so a sealed `message` cannot be relabelled an `ack`, and `length` cannot be edited without breaking the tag.

`keepalive` is not sealed. It has no payload at all, as specified in [frames.md](frames.md), so there is nothing to hide and a tag over nothing would authenticate nothing TLS does not already cover. The worst an injected keepalive achieves is a lie about liveness.

The session key protects the frame payload. The signature inside it protects authorship. Neither replaces the other: the seal says the bytes came from this session, the signature says who wrote them, and the signature is the one that still means something after the session is gone.

## What the session does not give

Forward secrecy here is per session. A message recovered from a device is still readable, because the message layer stores it; this protects recorded traffic, not storage.

There is no rekeying inside a session and no post compromise recovery. A session lives as long as the connection, and a connection on iOS dies when the app is suspended, so the natural session is short. A long lived session with an ephemeral stolen mid flight stays open until it closes.

Both peers must be online at the same time for any of this to happen. The handshake is not performed against a stored transcript.
