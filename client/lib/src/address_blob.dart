import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'codec.dart';
import 'contact_card.dart';
import 'exceptions.dart';
import 'identity.dart';
import 'peer_address.dart';

const String addressDomain = 'ios-registry-addr-v1';

const int _nonceLength = 12;
const int _macLength = 16;
const int _signatureLength = 64;

final Cipher _cipher = Chacha20.poly1305Aead();
final Hkdf _kdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

class AddressBlob {
  static Future<Uint8List> seal({
    required Identity author,
    required ContactCard recipient,
    required PeerAddress address,
    DateTime? publishedAt,
  }) async {
    address.validate();

    final stamp = (publishedAt ?? DateTime.now().toUtc()).toUtc();
    final inner = _buildInner(address: address, publishedAt: stamp);
    final signature = await author.sign(inner);

    final payload = FieldWriter()
      ..field(inner)
      ..field(signature);

    final ephemeral = await agreementAlgorithm.newKeyPair();
    final ephemeralPublicKey =
        Uint8List.fromList((await ephemeral.extractPublicKey()).bytes);

    final key = await _deriveKey(
      keyPair: ephemeral,
      remotePublicKey: recipient.agreementPublicKey,
      ephemeralPublicKey: ephemeralPublicKey,
    );

    final box = await _cipher.encrypt(payload.take(), secretKey: key);

    return (FieldWriter()
          ..raw(ephemeralPublicKey)
          ..raw(box.concatenation()))
        .take();
  }

  static Future<SignedPeerAddress> open({
    required Identity recipient,
    required ContactCard author,
    required Uint8List blob,
    Duration maxAge = const Duration(hours: 24),
    Duration maxSkew = const Duration(minutes: 5),
    DateTime? now,
  }) async {
    if (blob.length < keyLength + _nonceLength + _macLength) {
      throw const ProtocolException('address blob is too short');
    }

    final reader = FieldReader(blob);
    final ephemeralPublicKey = reader.raw(keyLength);
    final box = SecretBox.fromConcatenation(
      reader.raw(reader.remaining),
      nonceLength: _nonceLength,
      macLength: _macLength,
    );

    final key = await _deriveKey(
      keyPair: recipient.agreementKeyPair,
      remotePublicKey: ephemeralPublicKey,
      ephemeralPublicKey: ephemeralPublicKey,
    );

    final Uint8List payload;
    try {
      payload = Uint8List.fromList(await _cipher.decrypt(box, secretKey: key));
    } on SecretBoxAuthenticationError {
      throw const BlobAuthenticityException(
        'address blob is not sealed for this identity',
      );
    }

    final payloadReader = FieldReader(payload);
    final inner = payloadReader.field();
    final signature = payloadReader.field();
    payloadReader.expectEnd();

    if (signature.length != _signatureLength) {
      throw const BlobAuthenticityException('signature is not 64 bytes');
    }

    final verified = await signingAlgorithm.verify(
      inner,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(
          author.signingPublicKey,
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!verified) {
      throw const BlobAuthenticityException(
        'address blob was not signed by the expected author',
      );
    }

    return _parseInner(
      inner: inner,
      now: (now ?? DateTime.now().toUtc()).toUtc(),
      maxAge: maxAge,
      maxSkew: maxSkew,
    );
  }

  static Uint8List _buildInner({
    required PeerAddress address,
    required DateTime publishedAt,
  }) {
    return (FieldWriter()
          ..raw(utf8.encode(addressDomain))
          ..field(utf8.encode(address.host))
          ..field(uint16(address.port))
          ..field(int64(publishedAt.millisecondsSinceEpoch)))
        .take();
  }

  static SignedPeerAddress _parseInner({
    required Uint8List inner,
    required DateTime now,
    required Duration maxAge,
    required Duration maxSkew,
  }) {
    final domainBytes = utf8.encode(addressDomain);
    final reader = FieldReader(inner);

    if (!constantTimeEquals(reader.raw(domainBytes.length), domainBytes)) {
      throw const BlobAuthenticityException('wrong domain prefix');
    }

    final host = utf8.decode(reader.field());
    final port = readUint16(reader.field());
    final publishedAt = DateTime.fromMillisecondsSinceEpoch(
      readInt64(reader.field()),
      isUtc: true,
    );
    reader.expectEnd();

    if (publishedAt.isAfter(now.add(maxSkew))) {
      throw const BlobStaleException('address is stamped in the future');
    }
    if (now.difference(publishedAt) > maxAge) {
      throw const BlobStaleException('address is older than the accepted age');
    }

    final address = PeerAddress(host: host, port: port);
    address.validate();

    return SignedPeerAddress(address: address, publishedAt: publishedAt);
  }

  static Future<SecretKey> _deriveKey({
    required KeyPair keyPair,
    required List<int> remotePublicKey,
    required List<int> ephemeralPublicKey,
  }) async {
    if (remotePublicKey.length != keyLength) {
      throw const ProtocolException('agreement key is not 32 bytes');
    }

    final shared = await agreementAlgorithm.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: SimplePublicKey(
        remotePublicKey,
        type: KeyPairType.x25519,
      ),
    );

    return _kdf.deriveKey(
      secretKey: shared,
      nonce: ephemeralPublicKey,
      info: utf8.encode(addressDomain),
    );
  }
}
