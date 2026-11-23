import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'codec.dart';
import 'contact_card.dart';
import 'crypto.dart';
import 'exceptions.dart';

typedef IdentityDigestSigner = Future<Uint8List> Function(Uint8List digest);

class Identity {
  const Identity._({
    required ECPrivateKey? signingKey,
    required IdentityDigestSigner? digestSigner,
    required this.agreementKey,
    required this.signingPublicKey,
    required this.agreementPublicKey,
    required this.id,
  })  : _signingKey = signingKey,
        _digestSigner = digestSigner;

  final ECPrivateKey? _signingKey;
  final IdentityDigestSigner? _digestSigner;
  final ECPrivateKey agreementKey;
  final Uint8List signingPublicKey;
  final Uint8List agreementPublicKey;
  final String id;

  static Future<Identity> generate() async {
    return _from(
      generateKeyPair().privateKey,
      generateKeyPair().privateKey,
    );
  }

  static Future<Identity> fromExternalSigner({
    required List<int> signingPublicKey,
    required List<int> agreementSeed,
    required IdentityDigestSigner signDigest,
  }) async {
    if (agreementSeed.length != scalarLength) {
      throw const ProtocolException('an agreement seed must be 32 bytes');
    }

    decodePublicKey(signingPublicKey);
    final agreementKey = privateKeyFromScalar(agreementSeed);
    final signingBytes = Uint8List.fromList(signingPublicKey);
    final agreementPublicKey = encodePublicKey(publicKeyOf(agreementKey));

    return Identity._(
      signingKey: null,
      digestSigner: signDigest,
      agreementKey: agreementKey,
      signingPublicKey: signingBytes,
      agreementPublicKey: agreementPublicKey,
      id: await deriveId(
        signingPublicKey: signingBytes,
        agreementPublicKey: agreementPublicKey,
      ),
    );
  }

  static Future<Identity> fromSeeds({
    required List<int> signingSeed,
    required List<int> agreementSeed,
  }) async {
    if (signingSeed.length != scalarLength ||
        agreementSeed.length != scalarLength) {
      throw const ProtocolException('a seed must be 32 bytes');
    }
    return _from(
      privateKeyFromScalar(signingSeed),
      privateKeyFromScalar(agreementSeed),
    );
  }

  static Future<Identity> _from(
    ECPrivateKey signing,
    ECPrivateKey agreement,
  ) async {
    final signingPublicKey = encodePublicKey(publicKeyOf(signing));
    final agreementPublicKey = encodePublicKey(publicKeyOf(agreement));

    return Identity._(
      signingKey: signing,
      digestSigner: null,
      agreementKey: agreement,
      signingPublicKey: signingPublicKey,
      agreementPublicKey: agreementPublicKey,
      id: await deriveId(
        signingPublicKey: signingPublicKey,
        agreementPublicKey: agreementPublicKey,
      ),
    );
  }

  static Future<String> deriveId({
    required List<int> signingPublicKey,
    required List<int> agreementPublicKey,
  }) async {
    return hexEncode(sha256Of(<int>[
      ...signingPublicKey,
      ...agreementPublicKey,
    ]));
  }

  ContactCard get card => ContactCard(
        signingPublicKey: signingPublicKey,
        agreementPublicKey: agreementPublicKey,
        id: id,
      );

  Future<Uint8List> sign(List<int> message) async {
    final signer = _digestSigner;
    final signature = signer == null
        ? signMessage(key: _signingKey!, message: message)
        : await signer(sha256Of(message));
    if (signature.length != signatureLength) {
      throw const ProtocolException('a signature must be 64 bytes');
    }
    return signature;
  }

  Future<Map<String, String>> toJson() async {
    final signingKey = _signingKey;
    if (signingKey == null) {
      throw const ProtocolException(
        'an identity with an external signing key cannot be serialized',
      );
    }
    return <String, String>{
      'version': '2',
      'signingSeed': base64.encode(scalarToBytes(signingKey.d!)),
      'agreementSeed': base64.encode(scalarToBytes(agreementKey.d!)),
    };
  }

  static Future<Identity> fromJson(Map<String, dynamic> json) async {
    if (json['version'] != '2') {
      throw const ProtocolException('unsupported identity version');
    }
    final signingSeed = json['signingSeed'];
    final agreementSeed = json['agreementSeed'];
    if (signingSeed is! String || agreementSeed is! String) {
      throw const ProtocolException('identity is missing a seed');
    }

    return fromSeeds(
      signingSeed: base64.decode(signingSeed),
      agreementSeed: base64.decode(agreementSeed),
    );
  }
}
