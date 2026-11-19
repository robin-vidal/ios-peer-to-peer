import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'codec.dart';
import 'contact_card.dart';
import 'exceptions.dart';

final Ed25519 signingAlgorithm = Ed25519();
final X25519 agreementAlgorithm = X25519();
final Sha256 idHash = Sha256();

const int keyLength = 32;

class Identity {
  const Identity._({
    required this.signingKeyPair,
    required this.agreementKeyPair,
    required this.signingPublicKey,
    required this.agreementPublicKey,
    required this.id,
  });

  final SimpleKeyPair signingKeyPair;
  final SimpleKeyPair agreementKeyPair;
  final Uint8List signingPublicKey;
  final Uint8List agreementPublicKey;
  final String id;

  static Future<Identity> generate() async {
    final signing = await signingAlgorithm.newKeyPair();
    final agreement = await agreementAlgorithm.newKeyPair();
    return _from(signing, agreement);
  }

  static Future<Identity> fromSeeds({
    required List<int> signingSeed,
    required List<int> agreementSeed,
  }) async {
    if (signingSeed.length != keyLength || agreementSeed.length != keyLength) {
      throw const ProtocolException('a seed must be 32 bytes');
    }
    final signing = await signingAlgorithm.newKeyPairFromSeed(signingSeed);
    final agreement = await agreementAlgorithm.newKeyPairFromSeed(agreementSeed);
    return _from(signing, agreement);
  }

  static Future<Identity> _from(
    SimpleKeyPair signing,
    SimpleKeyPair agreement,
  ) async {
    final signingPublicKey =
        Uint8List.fromList((await signing.extractPublicKey()).bytes);
    final agreementPublicKey =
        Uint8List.fromList((await agreement.extractPublicKey()).bytes);

    return Identity._(
      signingKeyPair: signing,
      agreementKeyPair: agreement,
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
    final hash = await idHash.hash(<int>[
      ...signingPublicKey,
      ...agreementPublicKey,
    ]);
    return hexEncode(hash.bytes);
  }

  ContactCard get card => ContactCard(
        signingPublicKey: signingPublicKey,
        agreementPublicKey: agreementPublicKey,
        id: id,
      );

  Future<Uint8List> sign(List<int> message) async {
    final signature = await signingAlgorithm.sign(
      message,
      keyPair: signingKeyPair,
    );
    return Uint8List.fromList(signature.bytes);
  }

  Future<Map<String, String>> toJson() async {
    final signing = await signingKeyPair.extract();
    final agreement = await agreementKeyPair.extract();

    return <String, String>{
      'version': '1',
      'signingSeed': base64.encode(signing.bytes),
      'agreementSeed': base64.encode(agreement.bytes),
    };
  }

  static Future<Identity> fromJson(Map<String, dynamic> json) async {
    if (json['version'] != '1') {
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
