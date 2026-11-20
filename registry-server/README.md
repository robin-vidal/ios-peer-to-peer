# registry-server

Rendezvous server for the peer to peer chat. Peers authenticate with a key pair, publish their address encrypted for each contact, and fetch the address a contact published for them. Chat traffic never passes through here.

The wire protocol is specified in [docs/protocol.md](../docs/protocol.md).

## Build and run

```sh
go build -o registry-server .
REGISTRY_TLS_CERT=server.crt REGISTRY_TLS_KEY=server.key ./registry-server
```

The server refuses to start without a usable certificate and key. It never falls back to plaintext.

## Tests

```sh
go test ./...
```

They cover id derivation, the refusal of a key that is not a point on P-256, and every way a challenge signature can fail.

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `REGISTRY_ADDR` | `:8080` | listen address |
| `REGISTRY_TLS_CERT` | `server.crt` | PEM certificate |
| `REGISTRY_TLS_KEY` | `server.key` | PEM private key |

## Certificate

The certificate is self signed and pinned by the client, so no certificate authority is involved. Generate one with an address the client will actually dial in `subjectAltName`:

```sh
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
  -keyout server.key -out server.crt -days 365 -nodes \
  -subj "/CN=ios-registry" -addext "subjectAltName=IP:127.0.0.1"
```

Print the fingerprint to pin in the client:

```sh
openssl x509 -in server.crt -noout -fingerprint -sha256
```

Pinning this fingerprint is stronger than trusting a certificate authority: it also rejects an attacker holding a valid certificate signed by some other authority.

`server.key` is a private key. Keep it out of the repository.

## State

Everything lives in memory. A blob is held only while the connection that published it is open, and a restart clears all state.

That is the correct behavior rather than a shortcut: a stored address belongs to a connection, and a restart closes every connection it had. Persisting addresses would only serve stale ones to peers that are no longer reachable.

Public keys are not stored either. The server derives an id from the keys presented on each connection and indexes blobs by id, so it is never a key directory. Contacts exchange keys directly, which is what keeps the server from being able to substitute one.

## Not included

- **No relay.** The server hands out addresses; peers connect directly. A relay would hide peer addresses from each other, at the cost of carrying every message.
- **No contact list.** Access control is cryptographic: anyone may fetch a blob, only the intended contact can decrypt it. The server holds no social graph.
- **No accounts.** The id derived from the keys is the whole identity.
