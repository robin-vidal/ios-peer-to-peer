# Peer frame format

Peers exchange binary frames over a direct connection. The registry is not involved: it hands out an address and nothing else. For address discovery see [protocol.md](protocol.md), for what travels inside a frame see [chat.md](chat.md).

This document specifies framing only. It defines where one frame ends and the next begins, and nothing about what the payload means.

## Independence from TLS

Framing assumes an ordered, reliable byte stream and assumes nothing else. TLS sits under it as a separate layer, added by the peer session, and neither layer reads a field of the other. A frame is not a TLS record: a frame can span several records and several frames can arrive in one record, so a reader never treats a read boundary as a frame boundary.

Framing provides no confidentiality, no authenticity and no replay protection. All three come from elsewhere: the transport from TLS with both ends pinning the other's signing key, the message content from its own signature as specified in [chat.md](chat.md). A reader that trusts a frame because it parsed cleanly has misread this document.

## Header

Every frame begins with an 8 byte header, then the payload:

```
frame  = version (1) || type (1) || reserved (2) || length (4) || payload
```

| Field | Size | Value |
|---|---|---|
| `version` | 1 | `0x01` for this document |
| `type` | 1 | see the table below |
| `reserved` | 2 | `0x0000` on send, refused if non zero |
| `length` | 4 | payload length in bytes, uint32 big endian |
| `payload` | `length` | type dependent, may be empty |

Integers are big endian, as in the message layer. The header is fixed size, so a reader obtains `length` only after having read all 8 bytes, and never from a partial read.

`reserved` is refused rather than ignored. A field that is ignored becomes a channel: two implementations that disagree about whether it matters disagree about which bytes were authenticated.

## Maximum payload size

```
MAX_PAYLOAD = 65536
```

64 KiB, for every type. A text message does not approach it, and the cap is the bound on how much a peer can make the other side allocate before anything is authenticated.

Each type narrows it further, below. The limits are part of the format: a reader checks `length` against the limit for that type before reading the payload.

## Frame types

| Type | Name | Payload | Limit |
|---|---|---|---|
| `0x01` | `handshake` | one session handshake step | 1024 |
| `0x02` | `message` | `field(signed) \|\| field(sig)` of a chat message | `MAX_PAYLOAD` |
| `0x03` | `ack` | `field(signed) \|\| field(sig)` of an acknowledgement | 1024 |
| `0x04` | `keepalive` | empty | 0 |
| `0x05` | `heads` | reserved, never sent | refused |
| `0x06` | `chunk` | reserved, never sent | refused |
| `0x07` | `chunk-ack` | reserved, never sent | refused |

`0x00` is not a type and is refused, so a zero filled buffer is never a valid frame.

`field(x)` is the length prefixed form used in the message layer: `uint32` big endian length, then the bytes.

`0x05` is the equivocation detection frame, which belongs to group conversations. `0x06` and `0x07` carry media in chunks. Groups and media are out of scope, so these three numbers are assigned and nothing sends them. They are listed so that a later version cannot reuse a number for a different meaning.

### handshake

Carries one step of the peer session handshake: an ephemeral P-256 public key with a signature over it. The handshake is specified on its own, outside this document, since framing must not depend on which key agreement is in use.

A `handshake` frame after the session is established is refused. A `message`, `ack` or `keepalive` frame before it is established is refused.

### message and ack

The payload is the signed bytes and the signature, each length prefixed, exactly as produced by the message layer. Framing does not parse further. In particular a reader does not derive `msg_id` from the frame: it derives it from the signed bytes, after the signature verifies.

### keepalive

Empty payload, `length` zero. Sent when the connection has been idle for 20 seconds. A peer that has sent nothing for 60 seconds is treated as gone and the session is closed.

Presence is what the connection means here: there is no offline delivery, so a sender needs to know quickly that the other side is no longer there. Keepalive carries no payload precisely so that it cannot be used to make a peer allocate or parse anything.

## Refusals

A reader refuses a frame and closes the session, without a reply, when:

- `version` is not `0x01`
- `reserved` is not zero
- `type` is `0x00`, a reserved type, or a type this version does not define
- `length` exceeds the limit for that type
- `length` is below the fixed size the type requires
- the stream ends inside a header or inside a payload

Closing rather than skipping is deliberate. Skipping a frame of an unknown type requires trusting its `length` to find the next one, which hands an attacker control of the parser's position in the stream. Both ends of this protocol ship together, so there is no third party implementation that forward compatibility would serve.

No refusal is reported to the peer. An error reply is a parser reachable before authentication, and a distinguishable one tells a prober which check it tripped.

## Reading, in order

The order below is normative, since a reader that reorders it allocates from an unchecked length:

1. Read exactly 8 bytes. Fewer means the stream ended: close.
2. Check `version`, `reserved`, `type`.
3. Look up the limit for the type and check `length` against it, and against the minimum.
4. Only then allocate the payload buffer and read exactly `length` bytes.
5. Dispatch on the type.

A reader never allocates a buffer sized by a length it has not checked. This is the single property the hostile input tests exercise.
