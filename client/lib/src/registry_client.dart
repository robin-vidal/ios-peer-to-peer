import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'address_blob.dart';
import 'codec.dart';
import 'contact_card.dart';
import 'crypto.dart';
import 'exceptions.dart';
import 'identity.dart';
import 'peer_address.dart';
import 'wire.dart';

const String authDomain = 'ios-registry-auth-v1';

class RegistryClient {
  RegistryClient._({
    required WireConnection wire,
    required Identity identity,
    required Duration timeout,
    required this.myId,
  })  : _wire = wire,
        _identity = identity,
        _timeout = timeout;

  final WireConnection _wire;
  final Identity _identity;
  final Duration _timeout;

  final String myId;

  static Future<RegistryClient> connect({
    required String host,
    required int port,
    required String pinnedSha256,
    required Identity identity,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final expected = normalizeFingerprint(pinnedSha256);

    final socket = await SecureSocket.connect(
      host,
      port,
      onBadCertificate: (_) => true,
      timeout: timeout,
    );

    final certificate = socket.peerCertificate;
    if (certificate == null) {
      socket.destroy();
      throw const CertificatePinException('the server presented no certificate');
    }

    final actual = hexEncode(sha256Of(certificate.der));
    if (!constantTimeEquals(hexDecode(actual), hexDecode(expected))) {
      socket.destroy();
      throw CertificatePinException(
        'certificate fingerprint $actual does not match the pinned $expected',
      );
    }

    final wire = WireConnection(socket);
    final String id;
    try {
      id = await _handshake(wire: wire, identity: identity, timeout: timeout);
    } on Object {
      await wire.close();
      rethrow;
    }

    return RegistryClient._(
      wire: wire,
      identity: identity,
      timeout: timeout,
      myId: id,
    );
  }

  static Future<String> _handshake({
    required WireConnection wire,
    required Identity identity,
    required Duration timeout,
  }) async {
    final hello = 'HELLO '
        '${base64.encode(identity.signingPublicKey)} '
        '${base64.encode(identity.agreementPublicKey)}';

    final challenge = _expect(
      await wire.request(hello, timeout: timeout),
      keyword: 'CHALLENGE',
      fields: 2,
    );

    final nonce = base64.decode(challenge[1]);
    final signature = await identity.sign(<int>[
      ...utf8.encode(authDomain),
      ...nonce,
    ]);

    final ok = _expect(
      await wire.request('AUTH ${base64.encode(signature)}', timeout: timeout),
      keyword: 'OK',
      fields: 2,
    );

    if (ok[1] != identity.id) {
      throw ProtocolException(
        'the server derived id ${ok[1]} but this identity is ${identity.id}',
      );
    }
    return ok[1];
  }

  Future<void> publishAddress({
    required ContactCard to,
    required PeerAddress address,
  }) async {
    final blob = await AddressBlob.seal(
      author: _identity,
      recipient: to,
      address: address,
    );

    _expect(
      await _wire.request(
        'PUBLISH ${to.id} ${base64.encode(blob)}',
        timeout: _timeout,
      ),
      keyword: 'OK',
      fields: 1,
    );
  }

  Future<SignedPeerAddress?> fetchAddress({
    required ContactCard of,
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final reply = await _wire.request('FETCH ${of.id}', timeout: _timeout);
    throwIfServerError(reply);

    final fields = reply.split(' ');
    if (fields.length == 2 && fields[0] == 'NOTFOUND') {
      return null;
    }

    final blob = _expect(reply, keyword: 'BLOB', fields: 3);
    if (blob[1] != of.id) {
      throw ProtocolException(
        'the server returned a blob owned by ${blob[1]} instead of ${of.id}',
      );
    }

    return AddressBlob.open(
      recipient: _identity,
      author: of,
      blob: Uint8List.fromList(base64.decode(blob[2])),
      maxAge: maxAge,
    );
  }

  Future<void> close() async {
    await _wire.send('QUIT').onError((_, __) {});
    await _wire.close();
  }

  static List<String> _expect(
    String line, {
    required String keyword,
    required int fields,
  }) {
    throwIfServerError(line);

    final parts = line.split(' ');
    if (parts.length != fields || parts[0] != keyword) {
      throw ProtocolException('expected $keyword, got "$line"');
    }
    return parts;
  }
}

void throwIfServerError(String line) {
  if (line == 'ERR' || line.startsWith('ERR ')) {
    throw serverErrorFrom(line);
  }
}

String normalizeFingerprint(String fingerprint) {
  final cleaned = fingerprint
      .replaceAll(':', '')
      .replaceAll(' ', '')
      .replaceAll('sha256', '')
      .replaceAll('Fingerprint=', '')
      .toLowerCase();

  if (cleaned.length != 64) {
    throw CertificatePinException(
      'a pinned sha256 fingerprint must be 64 hex characters, got ${cleaned.length}',
    );
  }
  hexDecode(cleaned);
  return cleaned;
}
