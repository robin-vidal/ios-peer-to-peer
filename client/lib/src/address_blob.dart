import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'codec.dart';
import 'contact_card.dart';
import 'crypto.dart';
import 'exceptions.dart';
import 'identity.dart';
import 'peer_address.dart';

const String addressDomain = 'ios-registry-addr-v1';

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

    final ephemeral = generateKeyPair();
    final ephemeralPublicKey = encodePublicKey(ephemeral.publicKey);

    final key = _deriveKey(
      own: ephemeral.privateKey,
      peerPublicKey: recipient.agreementPublicKey,
      ephemeralPublicKey: ephemeralPublicKey,
    );

    return (FieldWriter()
          ..raw(ephemeralPublicKey)
          ..raw(aesGcmSeal(
            key: key,
            nonce: Uint8List(gcmNonceLength),
            associatedData: Uint8List(0),
            plaintext: payload.take(),
          )))
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
    if (blob.length < publicKeyLength + gcmTagLength) {
      throw const ProtocolException('address blob is too short');
    }

    final reader = FieldReader(blob);
    final ephemeralPublicKey = reader.raw(publicKeyLength);
    final sealed = reader.raw(reader.remaining);

    final key = _deriveKey(
      own: recipient.agreementKey,
      peerPublicKey: ephemeralPublicKey,
      ephemeralPublicKey: ephemeralPublicKey,
    );

    final Uint8List payload;
    try {
      payload = aesGcmOpen(
        key: key,
        nonce: Uint8List(gcmNonceLength),
        associatedData: Uint8List(0),
        ciphertext: sealed,
      );
    } on InvalidCipherTextException {
      throw const BlobAuthenticityException(
        'address blob is not sealed for this identity',
      );
    }

    final payloadReader = FieldReader(payload);
    final inner = payloadReader.field();
    final signature = payloadReader.field();
    payloadReader.expectEnd();

    if (signature.length != signatureLength) {
      throw const BlobAuthenticityException('signature is not 64 bytes');
    }

    final verified = verifyMessage(
      key: decodePublicKey(author.signingPublicKey),
      message: inner,
      signature: signature,
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

  static Uint8List _deriveKey({
    required ECPrivateKey own,
    required List<int> peerPublicKey,
    required List<int> ephemeralPublicKey,
  }) {
    return hkdfSha256(
      secret: agreedSecret(key: own, peer: decodePublicKey(peerPublicKey)),
      salt: ephemeralPublicKey,
      info: utf8.encode(addressDomain),
    );
  }
}