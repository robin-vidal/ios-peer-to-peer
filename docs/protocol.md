# Registry protocol

The registry is a rendezvous service. Peers use it to discover each other's address, then talk directly over their own connection, framed as in [frames.md](frames.md) and authenticated by the handshake in [session.md](session.md). It never carries chat traffic.

Every address it stores is encrypted for a single contact, so the registry holds bytes it cannot read.

## Transport

- TCP, TLS 1.3 minimum. A plaintext client is dropped during the handshake.
- The server certificate is self signed and pinned by the client. See `registry-server/README.md`.
- Line oriented. One request per line, one reply per line, terminated by `\n`.
- Maximum 2048 bytes per line. A longer line ends the connection.
- Fields are separated by runs of whitespace. Empty lines are ignored.
- Command verbs are case insensitive. Ids are lowercased on input.
- Base64 is standard encoding with padding. Ids are 64 lowercase hexadecimal characters.
- A connection has 10 seconds from accept to reach a successful `AUTH`, not extendable by sending commands. The TLS handshake runs inside that budget. Once authenticated there is no read timeout, since staying connected is what keeps a peer present, and a dead peer is caught by TCP keepalive.
- At most 10 `HELLO` attempts per connection, and at most 1024 concurrent connections server wide.

## Identity

A peer holds two key pairs:

| Key | Curve | Purpose |
|---|---|---|
| Signing | P-256 ECDSA | proves the peer holds its identity, signs blobs, signs the peer session handshake |
| Agreement | P-256 ECDH | lets contacts encrypt to the peer |

P-256 is not a preference. The Secure Enclave generates and holds P-256 keys only, so it is the one curve whose private half can stay in hardware and never reach the application.

Its id is derived from both public keys:

```
id = hex(SHA-256(sign_pub || agree_pub))
```

The client never sends its id. The server derives it from the keys presented during the handshake, so an id cannot be claimed without the matching signing key.

The id is the only identifier. There are no names and no accounts.

## Handshake

```
C: HELLO <p256-sign-pub-b64> <p256-agree-pub-b64>
S: CHALLENGE <nonce-b64>
C: AUTH <sig-b64>
S: OK <id>
```

Both public keys are 65 bytes, x963 uncompressed: a leading `0x04` then the two 32 byte coordinates. A key of the right length that is not a point on P-256 is refused like a malformed one. The nonce is 32 random bytes.

`sig` is a P-256 ECDSA signature over the SHA-256 of the concatenation of the ASCII domain prefix and the raw nonce, with no separator:

```
signed = "ios-registry-auth-v1" || nonce
sig    = ECDSA-P256-Sign(sign_priv, SHA-256(signed))
```

`sig` is 64 bytes: `r` then `s`, each 32 bytes big endian, zero padded. DER is not accepted, so there is no ASN.1 parser on the server and no length field an attacker can play with.

The prefix is 20 bytes and keeps the signature from being replayed into another protocol that signs raw nonces.

Nonce rules:

- fresh random value per `HELLO`
- valid 30 seconds from issue
- single use: any `AUTH` consumes it, success or failure, so a failed attempt needs a new `HELLO`
- scoped to its connection and never stored elsewhere

A new `HELLO` on an authenticated connection is refused. Re-authenticating means opening a new connection.

## Address exchange

```
C: PUBLISH <recipient-id> <blob-b64>
S: OK

C: FETCH <owner-id>
S: BLOB <owner-id> <blob-b64>
S: NOTFOUND <owner-id>
```

`PUBLISH` stores one blob per recipient. Publishing again for the same recipient replaces the previous blob. The owner is the authenticated id of the connection: no request field carries an owner, so a peer cannot publish an address under another id.

`FETCH` returns the blob the named owner published for the requesting id, and `NOTFOUND` when there is none. A peer therefore reads only the blob addressed to it.

Blobs are opaque. The server checks that a blob is valid base64 and at most 1024 encoded characters, stores it verbatim, and returns it verbatim.

An owner holds at most 64 blobs, so a peer can publish to 64 distinct recipients. Replacing the blob of an existing recipient still works at the cap.

## Blob contract

The blob format is a client side convention. The server does not parse, verify or understand any of it.

```
blob = Seal(contact_agree_pub, Sign(own_sign_priv, address || timestamp))
```

Each part earns its place:

- encrypting to the contact's agreement key is what restricts the address to that contact
- the signature tells the reader which peer wrote the blob, rather than only that it decrypted
- the timestamp lets the reader reject a stale address the server might hand back

A reader that skips the signature check learns an address with no author, and a reader that skips the timestamp accepts any address the server chooses to replay. Both checks are the client's responsibility.

One blob per contact, so a peer that changes network republishes once per contact.

## Lifetime

A blob lives as long as the connection that published it. When a connection closes, every blob it published is dropped, and only those.

One identity may hold several connections at once. This is the normal case on a mobile network: a peer that changes network reconnects before the server has noticed that the old connection is dead. The blobs of each connection are independent, so the old connection closing never drops a blob the new one published. Publishing for a recipient that already has a blob replaces it, and the blob then belongs to the connection that published last.

The cap of 64 recipients is per identity, not per connection: all the connections of one identity share it.

Presence is the connection, not a record. Nothing is persisted: a server restart clears all state, which is correct, since every address it held belonged to a connection that restart just closed.

## Replies

| Reply | Meaning |
|---|---|
| `CHALLENGE <nonce-b64>` | handshake accepted, sign this nonce |
| `OK <id>` | authenticated, this is your derived id |
| `OK` | blob stored |
| `BLOB <owner-id> <blob-b64>` | blob published by that owner for you |
| `NOTFOUND <owner-id>` | that owner published nothing for you |
| `BYE` | reply to `QUIT`, the server then closes |

## Errors

Every error is one line starting with `ERR`. Only `ERR too-many-handshakes` closes the connection.

| Error | Cause |
|---|---|
| `ERR unauthenticated` | any command other than `HELLO`, `AUTH` or `QUIT` before a successful `AUTH` |
| `ERR already-authenticated` | `HELLO` or `AUTH` on an authenticated connection |
| `ERR unknown-command` | unknown verb |
| `ERR usage <command> <args>` | wrong number of arguments |
| `ERR bad-key` | a public key is not valid base64, not 65 bytes, or not a point on P-256 |
| `ERR no-challenge` | `AUTH` with no live challenge, including a consumed one |
| `ERR stale-challenge` | the challenge is older than 30 seconds |
| `ERR bad-signature` | signature malformed, not 64 bytes, or not valid for the nonce |
| `ERR bad-id` | an id is not 64 hexadecimal characters |
| `ERR bad-blob` | the blob is not valid base64 |
| `ERR blob-too-large` | the blob exceeds 1024 encoded characters |
| `ERR too-many-recipients` | the owner already holds 64 blobs and the recipient is a new one |
| `ERR too-many-handshakes` | more than 10 `HELLO` on one connection, the server then closes |
| `ERR internal` | the server could not generate a nonce |

## What this protects, and what it does not

Protected:

- the network cannot read or forge the exchange, because the transport is TLS and the certificate is pinned
- a peer cannot claim an id it holds no key for, because ids are derived from keys
- a peer cannot publish an address under another id, because owners come from the session
- a non contact that fetches a blob cannot read it, because it holds no matching agreement key

Not protected:

- **The server observes peer addresses.** Each control connection carries its source address in the IP header, and no application layer encryption hides it. Encrypting blobs keeps the server from holding readable addresses at rest; it does not keep it from seeing who connects.
- **Contacts learn each other's address.** That is what direct connection means: a packet needs a destination. Hiding addresses between users requires a relay, which this design does not have.
- **Metadata leaks.** The server sees which ids publish to which ids, so it can infer the contact graph whether or not it keeps one.
- **Key substitution, if keys arrive through the server.** Nothing here binds a key to a person. Contacts must exchange keys out of band, by scanning a QR code in person. A key that changes later is an alert to raise, never a change to accept silently.
- **Truncated id comparison.** Displaying the first characters of an id is fine. Comparing on them is not: matching on 8 characters cuts collision resistance to 2^32. Always match all 64.