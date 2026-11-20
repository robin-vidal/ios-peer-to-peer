# registry_client

Dart client for the registry server. Pure Dart, no Flutter dependency, no native plugin, so it runs on iOS, Android, Windows, Linux and macOS. Not on web: it needs raw sockets.

All curve work is P-256, because the Secure Enclave generates and holds P-256 keys only. The private halves handled here are the ones a device cannot keep in hardware: ephemeral agreement keys, and the long term keys of a peer running without an enclave.

Wire protocol: [docs/protocol.md](../docs/protocol.md).

## What this does, and what it does not

It talks to the registry: identity, contact cards, and the encrypted exchange of one peer address per contact.

It carries **no chat**. There is no peer to peer transport, no messages, no acks, no groups, no media. After `fetchAddress` you hold a contact's address and nothing more.

## Usage

```dart
import 'package:registry_client/registry_client.dart';

final me = await Identity.generate();

final client = await RegistryClient.connect(
  host: 'registry.example.com',
  port: 8080,
  pinnedSha256: 'AA:BB:...',
  identity: me,
);

final contact = await ContactCard.decode(scannedQrPayload);

await client.publishAddress(
  to: contact,
  address: const PeerAddress(host: '192.168.1.42', port: 9000),
);

final theirs = await client.fetchAddress(of: contact);
if (theirs != null) {
  print('${theirs.address} published at ${theirs.publishedAt}');
}

await client.close();
```

`connect` performs `HELLO` and `AUTH` before returning, so a client you hold is an authenticated one.

`publishAddress` and `fetchAddress` do the sealing, signing, signature check and freshness check inside. Callers never touch a key.

## Identity

`Identity` holds a P-256 signing pair and a P-256 agreement pair. Public keys are 65 bytes, x963 uncompressed: a leading `0x04` then the two coordinates. Its `id` is the hex SHA-256 of both public keys, and the server derives the same value from the keys presented during the handshake, so an id cannot be claimed without the matching key.

`sign` hashes the message with SHA-256 and returns 64 bytes, `r` then `s`, each 32 bytes big endian. DER is never produced or accepted.

`toJson` emits the two 32 byte private scalars, base64 encoded. Store that in the Keychain, never in plain preferences. `fromJson` restores the same id and refuses a scalar outside the curve order.

A key held this way is a key the application can read. An enclave backed identity keeps the signing scalar in hardware instead, and this class is then the fallback for a peer that has no enclave.

`connect` compares the id the server returned against the locally derived one and fails if they differ.

## Contact cards

A card is the QR payload: `p2pchat:2:<signing-b64url>:<agreement-b64url>`. Public data only, so it needs no secrecy.

`decode` refuses a key that is not 65 bytes, not canonically encoded, or not a point on P-256, so an invalid curve point never reaches an agreement.

`decode` derives the id from the keys and never reads one off the wire, so a card cannot lie about its id. Two cards are equal when their keys are.

## Certificate pinning

`connect` accepts every certificate in the `onBadCertificate` callback and then compares the SHA-256 of the presented certificate against `pinnedSha256`, closing the socket on a mismatch.

The callback has to return true for this to work. It only fires for a certificate the platform does not already trust, so a check placed inside it would be skipped for a certificate signed by any public authority. Pinning has to be enforced outside it, on every connection, which is what this does.

`pinnedSha256` accepts the `openssl x509 -fingerprint -sha256` form with colons, or plain hex, in either case.

## Address blobs

```
inner  = "ios-registry-addr-v1" || field(host) || field(port) || field(timestamp)
sig    = ECDSA-P256(author, SHA-256(inner))
blob   = ephemeral P-256 public key (65) || AES-GCM(K, field(inner) || field(sig))
K      = HKDF-SHA256(ECDH(ephemeral, recipient agreement key), salt = ephemeral public key, info = domain)
```

Fields are length prefixed, so no two different addresses produce the same signed bytes. The GCM nonce is zero: the key is derived from a fresh ephemeral key for every blob, so it is never reused.

`open` fails with `BlobAuthenticityException` when the blob was sealed for someone else, when the signature does not match the expected author, or when a byte changed. It fails with `BlobStaleException` for an address older than `maxAge`, 24 hours by default, or stamped more than five minutes in the future.

Verifying the author is the caller's job to request: pass the card of the peer you expect, and a blob signed by anyone else is refused.

## Errors

Every `ERR` token from the server maps to a subclass of `ServerErrorException`, so `TooManyRecipientsException` and `StaleChallengeException` are caught by type rather than by string. `ProtocolException` covers a reply that does not fit the grammar, `CertificatePinException` a fingerprint mismatch.

## Tests

```sh
dart test
```

Unit tests cover id derivation, the refusal of a key that is not a point on P-256, the card codec, and sealing. The integration test builds and runs the real Go server with a generated certificate, then drives the full handshake, publish and fetch, including the 64 recipient cap and the drop of blobs on disconnect. It skips itself when `go` or `openssl` is missing.
