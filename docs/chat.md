# Chat message layer

Messages travel peer to peer. The registry never sees one, so every guarantee comes from the message format itself. This is a client side convention: no server implements any of it.

For address discovery, see [protocol.md](protocol.md). For how these bytes are delimited on the peer connection, see [frames.md](frames.md).

## Scope

Everything provable without a trusted ordering authority is proven here. One thing is not, and is not worked around: **completeness**. No peer can prove that nothing else was said.

## Encoding

Every field is length prefixed so that two different messages cannot produce the same signed bytes:

```
field = uint32 big endian length || bytes
```

Without the prefixes, moving one byte from `conversation_id` into `author_id` would yield identical signed bytes, and one signature would cover two different messages.

A `conversation_id` is 32 random bytes chosen by the creator. An `author_id` or `recipient_id` is the raw 32 byte form of the registry id, not its hex text.

## Message

```
signed = "ios-chat-msg-v1"
      || field(conversation_id)   32 bytes
      || field(author_id)         32 bytes
      || field(seq)                8 bytes, uint64 big endian
      || field(timestamp)          8 bytes, int64 big endian, unix milliseconds
      || field(parents)            n * 32 bytes
      || field(keys)               n * 145 bytes
      || field(body)

sig    = ECDSA-P256-Sign(author_signing_key, SHA-256(signed))
msg_id = SHA-256(signed)
```

`msg_id` hashes `signed`, never `sig`. ECDSA signatures are malleable, so an id derived from one would not be unique to a message.

`seq` counts per conversation and per author, starting at 1, with no gaps.

`parents` lists the `msg_id` of every message the author had seen with no known child. The history is a graph, not a list.

`timestamp` is advisory. Clocks lie, and nothing verifies them. Ordering comes from `parents` and `seq`, never from time.

## Body and group keys

The body is encrypted once, under a fresh random key per message:

```
body       = AES-GCM(K, zero nonce, plaintext)
keys entry = recipient_id (32) || sealed K (113)
sealed K   = P-256 ephemeral public key (65) || AES-GCM of K (48)
```

The zero nonce is safe because `K` is random and used for exactly one message.

Encrypting the body once and wrapping `K` per recipient matters beyond efficiency: every recipient receives **identical signed bytes**, so `msg_id` is the same for everyone and the graph stays consistent across the group. Encrypting the plaintext separately per recipient would give each one a different `msg_id`, and no two members could ever agree on a parent.

A group of N means N entries in `keys`, and N-1 direct sends. There is no fanout service.

## Acknowledgement

```
signed = "ios-chat-ack-v1"
      || field(conversation_id)
      || field(msg_id)
      || field(acker_id)
      || field(timestamp)
```

Signed, so an ack cannot be forged for someone else. Redelivery is idempotent: a message already known by `msg_id` is dropped.

A sender retries on reconnect until acked. Both peers must be online at the same time, otherwise nothing is delivered, and on iOS a suspended app holds no connection.

## Equivocation detection

Members exchange a signed statement of their current graph heads:

```
signed = "ios-chat-heads-v1"
      || field(conversation_id)
      || field(heads)        n * 32 bytes
      || field(timestamp)
```

Two members comparing heads detect a member that told them different histories. Signing it makes the fork provable afterwards rather than a claim.

## What is proven

| Property | Mechanism | Assumption |
|---|---|---|
| Authorship | ECDSA P-256 over `SHA-256(signed)`, key held in the Secure Enclave and bound to a person by in person QR scan | the device is not compromised while unlocked |
| Conversation binding | `conversation_id` inside `signed`, plus the domain prefix | none |
| Order within an author | `seq` inside `signed`, contiguous | none |
| Tamper evidence | `msg_id` is a hash of `signed`, parents reference ids | none |
| No fabrication by a peer | a peer holds no other member's signing key | the other key is not compromised |
| Omission mid stream | a gap in an author's `seq` | none |
| Omission at the tail | a parent reference to an unknown `msg_id` | some later message references the hidden one |
| Equivocation | comparing signed heads | at least one honest member is reachable |
| Non repudiation of what was said | the signed message is kept | none |
| Replay and duplicates | idempotence on `msg_id` | none |

## What is not proven

| Not proven | Why |
|---|---|
| Completeness | proving that nothing else was said requires a trusted total order. With two colluding members out of three there is no honest witness and nothing to detect. Accepted bound. |
| Non receipt | a recipient can always withhold an ack. Delivery is provable when it cooperates, never its absence. |
| Time | timestamps are unverifiable. Only causal order is evidence. |
| Hiding addresses from members | a direct connection needs a destination. See protocol.md. |

Signal and WhatsApp do not defend against n-1 colluding members either. The bound is not specific to this design.

## Sync on rejoin

A returning member asks **every** reachable member for the missing history and takes the union. That moves the trust from one peer being honest to at least one being honest, which is the cheapest real gain available here.

Omissions are then detected by `seq` gaps and dangling parents, not prevented.
