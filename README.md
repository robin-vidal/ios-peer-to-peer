<p align="center">
  <img src="docs/assets/logo.png" alt="ios-peer-to-peer" width="96" height="96">
</p>

<p align="center">
  <a href="https://github.com/robin-vidal/ios-peer-to-peer/actions/workflows/ci.yml"><img src="https://github.com/robin-vidal/ios-peer-to-peer/actions/workflows/ci.yml/badge.svg" alt="ci"></a>
  <a href="https://github.com/robin-vidal/ios-peer-to-peer/tags"><img src="https://img.shields.io/github/v/tag/robin-vidal/ios-peer-to-peer?label=version&color=0071E3" alt="version"></a>
</p>

# ios-peer-to-peer

Peer to peer text chat between two iOS devices, with the long term signing key held in the Secure Enclave. A server exists only so two peers learn each other's address. Specs and the registry layer are done; the peer transport and the chat layer are not written yet.

## Components

| Directory | Responsibility |
|---|---|
| [`registry-server`](registry-server/README.md) | Go rendezvous. Authenticates a peer by its keys, holds one encrypted address blob per recipient while the publisher stays connected. No chat traffic, no key directory. |
| [`client`](client/README.md) | Dart package, no Flutter: identities, contact cards, address blobs, registry protocol, certificate pinning. |
| `app` | Flutter iOS application: identity, QR exchange, contacts, conversation. Reaches the enclave through a Swift plugin. |

Specs: [protocol.md](docs/protocol.md), [frames.md](docs/frames.md), [session.md](docs/session.md), [chat.md](docs/chat.md).

## Security model

P-256 everywhere, because the Secure Enclave holds P-256 keys only and it is the root of trust. An id is the SHA-256 of both public keys, so it cannot be claimed without them, and contacts enter only by in person QR scan, so nothing can substitute a key. The registry is a stateless rendezvous that sees ciphertext only, and peer traffic is sealed under session keys from a signed ephemeral ECDH, so recorded traffic survives a seized device.

An enclave key proves the device, not the person.

Out of scope: groups, media, offline delivery, push. Both peers must be online at once.

## Running it

Run against Go 1.27, Dart 3.14, Flutter 3.50.

```sh
R=$(git rev-parse --show-toplevel)
(cd "$R/registry-server" && go build -o registry-server . && go vet ./... && go test ./...)
(cd "$R/client" && dart pub get && dart analyze --fatal-infos && dart test)
(cd "$R/app" && flutter pub get && flutter analyze && flutter test)
```

The server refuses to start without a certificate, which is self signed and pinned by the client:

```sh
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
  -keyout server.key -out server.crt -days 365 -nodes \
  -subj "/CN=ios-registry" -addext "subjectAltName=IP:127.0.0.1"
openssl x509 -in server.crt -noout -fingerprint -sha256
REGISTRY_TLS_CERT=server.crt REGISTRY_TLS_KEY=server.key ./registry-server
```

`server.key` stays out of the repository. Running the app on a device needs Xcode; the checks above do not.

## Security dossier

The STRIDE analysis, MASVS grid, SAST and DAST reports, SBOM and cross audit are not published here. They are handed over out of band as one encrypted archive, per issue #55: the cross audit carries another team's weaknesses.

## License

MIT, see [LICENSE](LICENSE).
