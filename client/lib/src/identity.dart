import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'codec.dart';
import 'contact_card.dart';
import 'crypto.dart';
import 'exceptions.dart';

class Identity {
  const Identity._({
    required this.signingKey,
    required this.agreementKey,
    required this.signingPublicKey,
    required this.agreementPublicKey,
    required this.id,
  });

  final ECPrivateKey signingKey;
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
    return signMessage(key: signingKey, message: message);
  }

  Future<Map<String, String>> toJson() async {
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
