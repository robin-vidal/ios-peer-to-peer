import 'dart:typed_data';

import 'package:registry_client/registry_client.dart';
import 'package:registry_client/src/crypto.dart';
import 'package:test/test.dart';

void main() {
  test('id is 64 lowercase hex characters', () async {
    final identity = await Identity.generate();

    expect(identity.id, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(identity.signingPublicKey, hasLength(publicKeyLength));
    expect(identity.agreementPublicKey, hasLength(publicKeyLength));
    expect(identity.signingPublicKey.first, 0x04);
    expect(identity.agreementPublicKey.first, 0x04);
  });

  test('id derivation is deterministic and order sensitive', () async {
    final signing = Uint8List.fromList(List<int>.filled(publicKeyLength, 1));
    final agreement = Uint8List.fromList(List<int>.filled(publicKeyLength, 2));

    final first = await Identity.deriveId(
      signingPublicKey: signing,
      agreementPublicKey: agreement,
    );
    final second = await Identity.deriveId(
      signingPublicKey: signing,
      agreementPublicKey: agreement,
    );
    final swapped = await Identity.deriveId(
      signingPublicKey: agreement,
      agreementPublicKey: signing,
    );

    expect(first, second);
    expect(first, isNot(swapped));
  });

  test('serialization round trip preserves the identity', () async {
    final original = await Identity.generate();
    final restored = await Identity.fromJson(await original.toJson());

    expect(restored.id, original.id);
    expect(restored.signingPublicKey, original.signingPublicKey);
    expect(restored.agreementPublicKey, original.agreementPublicKey);
  });

  test('signatures verify against the published signing key', () async {
    final identity = await Identity.generate();
    final message = <int>[1, 2, 3, 4];
    final signature = await identity.sign(message);

    expect(signature, hasLength(signatureLength));

    final key = decodePublicKey(identity.signingPublicKey);
    expect(
      verifyMessage(key: key, message: message, signature: signature),
      isTrue,
    );
    expect(
      verifyMessage(
        key: key,
        message: <int>[1, 2, 3, 5],
        signature: signature,
      ),
      isFalse,
    );
  });

  test('an external signer receives the SHA-256 digest and cannot serialize', () async {
    final signing = await Identity.generate();
    final agreementSeed = scalarToBytes(BigInt.from(7));
    Uint8List? receivedDigest;
    final identity = await Identity.fromExternalSigner(
      signingPublicKey: signing.signingPublicKey,
      agreementSeed: agreementSeed,
      signDigest: (digest) async {
        receivedDigest = digest;
        return Uint8List.fromList(List<int>.filled(signatureLength, 1));
      },
    );

    final signature = await identity.sign(<int>[1, 2, 3]);

    expect(signature, hasLength(signatureLength));
    expect(receivedDigest, sha256Of(<int>[1, 2, 3]));
    await expectLater(
      identity.toJson(),
      throwsA(isA<ProtocolException>()),
    );
  });

  test('a signature of the wrong length is refused', () async {
    final identity = await Identity.generate();
    final message = <int>[1, 2, 3, 4];
    final signature = await identity.sign(message);
    final key = decodePublicKey(identity.signingPublicKey);

    expect(
      verifyMessage(
        key: key,
        message: message,
        signature: signature.sublist(0, 63),
      ),
      isFalse,
    );
    expect(
      verifyMessage(
        key: key,
        message: message,
        signature: Uint8List(signatureLength),
      ),
      isFalse,
    );
  });

  test('a key that is not a point on P-256 is refused', () async {
    final identity = await Identity.generate();
    final broken = Uint8List.fromList(identity.signingPublicKey);
    broken[broken.length - 1] ^= 0x01;

    expect(
      () => decodePublicKey(broken),
      throwsA(isA<ProtocolException>()),
    );
    expect(
      () => decodePublicKey(identity.signingPublicKey.sublist(0, 64)),
      throwsA(isA<ProtocolException>()),
    );
  });

  test('seeds must be 32 bytes', () async {
    expect(
      () => Identity.fromSeeds(
        signingSeed: List<int>.filled(16, 0),
        agreementSeed: List<int>.filled(scalarLength, 1),
      ),
      throwsA(isA<ProtocolException>()),
    );
  });

  test('a seed outside the curve order is refused', () async {
    expect(
      () => Identity.fromSeeds(
        signingSeed: List<int>.filled(scalarLength, 0),
        agreementSeed: List<int>.filled(scalarLength, 1),
      ),
      throwsA(isA<ProtocolException>()),
    );
    expect(
      () => Identity.fromSeeds(
        signingSeed: List<int>.filled(scalarLength, 0xff),
        agreementSeed: List<int>.filled(scalarLength, 1),
      ),
      throwsA(isA<ProtocolException>()),
    );
  });

  test('an unsupported serialization version is rejected', () async {
    expect(
      () => Identity.fromJson(<String, dynamic>{'version': '1'}),
      throwsA(isA<ProtocolException>()),
    );
  });
}
