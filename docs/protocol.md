# Registry protocol

The registry is a rendezvous service. Peers use it to discover each other's address, then talk directly over their own connection, framed as in [frames.md](frames.md) and authenticated by the handshake in [session.md](session.md). It never carries chat traffic.

Every address it stores is encrypted for a single contact, so the registry holds bytes it cannot read.

## Transport

- TCP, TLS 1.3 minimum. A plaintext client is dropped during the handshake.
- The server certificate is self signed and pinned by the client. See `registry-server/README.md`.
- Line oriented. One request per line, one reply per line, terminated by `\n`.
- Maximum 2048 bytes per line. A longer line ends the connection, and the close is silent: the read that would have returned the line fails first, so no `ERR` is sent and the client sees only a closed socket.
- Fields are separated by runs of whitespace. Empty lines are ignored.
- Command verbs are case insensitive. Ids are lowercased on input.
- Base64 is standard encoding with padding. Ids are 64 lowercase hexadecimal characters.
- A connection has 10 seconds from accept to reach a successful `AUTH`, not extendable by sending commands. The TLS handshake runs inside that budget.
- Once authenticated the read deadline is cleared, since staying connected is what keeps a peer present, and a dead peer is caught by TCP keepalive every 30 seconds. The intended bound on an authenticated connection is 30 minutes with no command, after which the server closes it and the peer reconnects and republishes, which it has to do anyway because a blob lives only as long as the connection that published it. That bound is stated here before it exists in the server: today a connection that authenticates and then goes silent holds its slot until the peer or the network drops it.
- Every reply has 10 seconds to reach the client. A peer that stops reading is closed when that deadline passes, and that close is silent too: the only channel an `ERR` could travel on is the one that is blocked.
- At most 10 `HELLO` attempts per connection, at most 16 concurrent connections from one source address, and at most 1024 concurrent connections server wide. The per source bound is 16 and not 1 because several peers can share one public address behind NAT. Without it one client reaches the server wide ceiling on its own. Like the idle bound, this one is intent and not yet behaviour: the server counts connections only in total.

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

The 30 second window is longer than the 10 second budget from accept to `AUTH`, and that budget is one absolute deadline on the connection rather than a timer reset per command. A challenge therefore cannot still be live when it expires: the connection is closed first. `ERR stale-challenge` is unreachable over the wire and is exercised by a unit test that passes its own clock to the verifier, in `registry-server/identity_test.go`. The check stays in the code, and the row stays in the table below, because the deadline that masks it is a transport decision that a later version may change.

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

A recipient id is checked for being 64 hexadecimal characters and against nothing else. The server holds no list of identities, so a `PUBLISH` for an id that no live connection owns, and that the server has never seen, answers `OK` and stores the blob until the owner disconnects. That is not a missing check: there is no directory to check against, and a blob is readable only by the holder of the matching agreement key.

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

A blob lives as long as the connection that published it. When the owner disconnects, every blob it published is dropped.

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

Every error is one line starting with `ERR`. Only `ERR too-many-handshakes` closes the connection after sending an error. The other closes described under Transport, an over long line and either deadline, send nothing at all.

| Error | Cause |
|---|---|
| `ERR unauthenticated` | any command other than `HELLO`, `AUTH` or `QUIT` before a successful `AUTH` |
| `ERR already-authenticated` | `HELLO` or `AUTH` on an authenticated connection |
| `ERR unknown-command` | unknown verb |
| `ERR usage <command> <args>` | wrong number of arguments |
| `ERR bad-key` | a public key is not valid base64, not 65 bytes, or not a point on P-256 |
| `ERR no-challenge` | `AUTH` with no live challenge, including a consumed one |
| `ERR stale-challenge` | the challenge is older than 30 seconds, masked by the connection deadline as described above |
| `ERR bad-signature` | signature malformed, not 64 bytes, or not valid for the nonce |
| `ERR bad-id` | an id is not 64 hexadecimal characters |
| `ERR bad-blob` | the blob is not valid base64 |
| `ERR blob-too-large` | the blob exceeds 1024 encoded characters |
| `ERR too-many-recipients` | the owner already holds 64 blobs and the recipient is a new one |
| `ERR too-many-handshakes` | more than 10 `HELLO` on one connection, the server then closes |
| `ERR internal` | the server could not generate a nonce |

### Order of refusals

When a line could be refused for more than one reason, the reply is the first match in this order, fixed here so that a test can assert it:

- the authentication gate runs before the verb is dispatched and before any argument is counted, so an unknown verb and a verb with the wrong argument count both answer `ERR unauthenticated` when they arrive before a successful `AUTH`
- `HELLO` counts against the 10 attempt limit before it is parsed, so a malformed `HELLO` still consumes an attempt, and the eleventh attempt is refused whatever it carries
- `HELLO` and `AUTH` on an authenticated connection answer `ERR already-authenticated` before their arguments are counted
- `HELLO` checks the argument count, then the signing key, then the agreement key, and a refused `HELLO` clears any challenge the connection held
- `AUTH` checks the argument count, then the presence of a live challenge, then its age, then that an identity was parsed by a previous `HELLO`, then the signature
- `PUBLISH` checks the argument count, then the recipient id, then the encoded blob length, then base64 validity, then the 64 recipient cap
- `FETCH` checks the argument count, then the owner id, then the lookup, which answers `NOTFOUND` and not `ERR`

A reply that does not follow this order is a finding, not an implementation detail.

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
