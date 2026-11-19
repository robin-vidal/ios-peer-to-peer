import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:registry_client/registry_client.dart';
import 'package:test/test.dart';

void main() {
  test('id is 64 lowercase hex characters', () async {
    final identity = await Identity.generate();

    expect(identity.id, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(identity.signingPublicKey, hasLength(keyLength));
    expect(identity.agreementPublicKey, hasLength(keyLength));
  });

  test('id derivation is deterministic and order sensitive', () async {
    final signing = Uint8List.fromList(List<int>.filled(keyLength, 1));
    final agreement = Uint8List.fromList(List<int>.filled(keyLength, 2));

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

    expect(signature, hasLength(64));

    final verified = await Ed25519().verify(
      message,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(
          identity.signingPublicKey,
          type: KeyPairType.ed25519,
        ),
      ),
    );
    expect(verified, isTrue);

    final tampered = await Ed25519().verify(
      <int>[1, 2, 3, 5],
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(
          identity.signingPublicKey,
          type: KeyPairType.ed25519,
        ),
      ),
    );
    expect(tampered, isFalse);
  });

  test('seeds must be 32 bytes', () async {
    expect(
      () => Identity.fromSeeds(
        signingSeed: List<int>.filled(16, 0),
        agreementSeed: List<int>.filled(keyLength, 0),
      ),
      throwsA(isA<ProtocolException>()),
    );
  });

  test('an unsupported serialization version is rejected', () async {
    expect(
      () => Identity.fromJson(<String, dynamic>{'version': '2'}),
      throwsA(isA<ProtocolException>()),
    );
  });
}
