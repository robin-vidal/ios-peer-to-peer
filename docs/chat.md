# Chat message layer

Messages travel peer to peer. The registry never sees one, so every guarantee comes from the message format itself. This is a client side convention: no server implements any of it.

For address discovery, see [protocol.md](protocol.md). For how these bytes are delimited on the peer connection, see [frames.md](frames.md), and for the session they are sealed under, [session.md](session.md).

## Scope

A conversation has exactly two participants, and both hold the other's contact card from an in person QR scan. Groups, media and history sync are out of scope, and the fields that only existed to serve them are gone rather than left unused. The last section says what was cut and why.

Everything provable without a trusted ordering authority is proven here. Two things are not, and are not worked around: **completeness** and **non receipt**. No peer can prove that nothing else was said, and no sender can prove that a delivered message was read.

## Encoding

Every field is length prefixed so that two different messages cannot produce the same signed bytes:

```
field = uint32 big endian length || bytes
```

Without the prefixes, moving one byte from `conversation_id` into `author_id` would yield identical signed bytes, and one signature would cover two different messages.

An `author_id` or `recipient_id` is the raw 32 byte form of the registry id, not its hex text.

A `conversation_id` is derived from the two identities rather than chosen:

```
conversation_id = SHA-256("ios-chat-conv-v1" || field(id_low) || field(id_high))     32 bytes
```

`id_low` and `id_high` are the two 32 byte ids ordered as unsigned byte strings, so both peers compute the same value without exchanging anything. A random id would need an owner to pick it, and two participants have no creator: both can compose a first message at the same time, and two random ids for one conversation have nothing to reconcile them. Deriving it also binds the conversation to the pair, so a signed message cannot be replayed into a conversation with somebody else.

## Message

```
signed = "ios-chat-msg-v1"
      || field(conversation_id)   32 bytes
      || field(author_id)         32 bytes
      || field(seq)                8 bytes, uint64 big endian
      || field(timestamp)          8 bytes, int64 big endian, unix milliseconds
      || field(keys)             145 bytes, exactly one entry
      || field(body)

sig    = ECDSA-P256-Sign(author_signing_key, SHA-256(signed))
msg_id = SHA-256(signed)
```

`msg_id` hashes `signed`, never `sig`. ECDSA signatures are malleable, so an id derived from one would not be unique to a message.

`seq` counts per conversation and per author, starting at 1, with no gaps. It is the only ordering field. Each peer therefore keeps two counters per conversation: the next value it will send, and the next value it expects to receive.

`timestamp` is advisory. Clocks lie, and nothing verifies them. Ordering comes from `seq`, never from time.

## Body and the message key

The body is encrypted under a fresh random key per message, and that key is wrapped for the recipient:

```
K          = 32 random bytes, one message only
body       = AES-GCM(K, zero nonce, plaintext)                    plaintext + 16 bytes

E          = a fresh P-256 ephemeral pair, one message only
K_wrap     = HKDF-SHA256(ikm  = ECDH(E private, recipient agreement key),
                         salt = E public key,
                         info = "ios-chat-key-v1",
                         L    = 32)
sealed K   = E public key (65) || AES-GCM(K_wrap, zero nonce, K)   65 + 48
keys entry = recipient_id (32) || sealed K (113)                   145
```

This is the construction an address blob already uses, written out in [the client package](../client/README.md), with its own `info` string so a wrapped key is never a blob key and the two cannot be swapped.

Both zero nonces are safe, for the same reason in both places: `K` is random and encrypts exactly one body, and `K_wrap` is derived from an ephemeral pair generated for exactly one message. A nonce is reused only when a key is, and neither key outlives its message.

`keys` holds exactly one entry, the recipient, and a decoder refuses a `keys` field whose length is not 145 or whose `recipient_id` is not the local identity. A second entry would mean a second reader of the same body, which this scope does not have.

Wrapping `K` rather than encrypting the plaintext directly keeps the signed bytes independent of the key agreement. The sender's long term agreement key is never involved, so losing it opens nothing. The recipient's is, which is the limit of this construction: recovered later, it unwraps every `K` ever sent to that recipient. Recorded traffic is out of its reach anyway, because the frame payload carrying all of this is sealed again under the session keys of [session.md](session.md), and those die with the session. What it does reach is a message the recipient still stores.

## Size limits

The plaintext body is capped at 63 KiB, 64512 bytes, and a longer one is refused at composition. The cap comes from the frame layer, where a `message` payload cannot exceed `MAX_PAYLOAD`, 65536 bytes, see [frames.md](frames.md). The remaining kilobyte covers the signed header fields, the wrapped key, the GCM tag of the body, the signature, the two length prefixes the frame payload adds and the 16 byte tag of the session seal. That overhead is 368 bytes against the 1024 the cap leaves, so a body at the limit frames to 64880 bytes and 656 remain unused.

Refusing at composition rather than at framing is deliberate. A message checked only on the way out has already been signed, given an `msg_id` and stored before it is found to be unsendable.

## Acknowledgement

```
signed = "ios-chat-ack-v1"
      || field(conversation_id)
      || field(msg_id)
      || field(acker_id)
      || field(timestamp)
```

Signed, so an ack cannot be forged for someone else. Redelivery is idempotent: a message already known by `msg_id` is dropped.

A sender retries on reconnect until acked. Both peers must be online at the same time, otherwise nothing is delivered, and on iOS a suspended app holds no connection. An unacked message waits in the sender's outbox.

An ack states delivery to the device, not that anybody read it.

## Ordering and gaps

A receiver accepts a message when `seq` is exactly the value it expects from that author, then increments.

A higher `seq` means something is missing. The message is held, not dropped and not shown out of order, and the conversation is marked incomplete until the gap is filled by a retry. A lower or repeated `seq` is a duplicate and is dropped by `msg_id`.

A gap that never fills is visible to the user rather than silently closed. The sender is the only party that can fill it, so a gap that persists means either a connection that never recovered or a counterparty that chose not to resend, and nothing in the format distinguishes those two.

## What is proven

| Property | Mechanism | Assumption |
|---|---|---|
| Authorship | ECDSA P-256 over `SHA-256(signed)`, key held in the Secure Enclave and bound to a person by in person QR scan | the device is not compromised while unlocked |
| Conversation binding | `conversation_id` inside `signed`, plus the domain prefix | none |
| Order within an author | `seq` inside `signed`, contiguous | none |
| Tamper evidence | `msg_id` is a hash of `signed`, and the body carries a GCM tag under a key only the recipient can unwrap | none |
| No fabrication by the other peer | a peer holds no part of the other's signing key | the other key is not compromised |
| Omission mid stream | a gap in an author's `seq` | a later message from the same author arrives |
| Confidentiality of the body | AES-GCM under a per message key, sealed to the recipient's agreement key | the recipient's device is not compromised |
| Non repudiation of what was said | the signed message is kept | none |
| Replay and duplicates | idempotence on `msg_id`, and `seq` is already consumed | none |

## What is not proven

| Not proven | Why |
|---|---|
| Completeness | proving that nothing else was said requires a trusted total order. With two participants the counterparty is the only witness, so a withheld message leaves no honest third party to contradict it. Accepted bound. |
| Omission at the tail | the last message of a stream can be withheld with no gap left behind, since nothing follows it to reference the missing `seq`. Detection needs traffic that does not exist yet. |
| Non receipt | a recipient can always withhold an ack. Delivery is provable when it cooperates, never its absence. |
| Reading | an ack is produced by the device on delivery, and no signature can state that a person looked at the screen. |
| Time | timestamps are unverifiable. Only `seq` is evidence of order. |
| Hiding addresses from a contact | a direct connection needs a destination. See [protocol.md](protocol.md). |

## What was cut, and why

Dropped with groups, kept here as a record so a later version does not reuse the same names for something else:

- **A parent graph.** Messages referenced the ids of every message their author had seen with no known child, which ordered a history across several authors. With two participants, two per author sequences carry the same order at a fraction of the state.
- **Equivocation detection.** Members exchanged a signed statement of their current graph heads, and two of them comparing heads caught a third that had told them different histories. It needs at least three participants and an honest one among them, so it has nothing to detect in a two party conversation. Frame type `0x05` stays reserved for it.
- **Per recipient key fanout.** `keys` carried one entry per member, which let every member receive identical signed bytes and therefore agree on one `msg_id`. One recipient makes the fanout a single entry.
- **History sync on rejoin.** A returning member asked every reachable member for the missing history and took the union, moving the trust from one peer being honest to at least one being honest. With one counterparty there is no union to take.
- **Media in chunks.** Frame types `0x06` and `0x07` stay reserved and nothing sends them. Text only, within the body cap above.
