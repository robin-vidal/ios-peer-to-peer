import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2pchat/app_identity.dart';
import 'package:p2pchat/secure_enclave_signing.dart';
import 'package:registry_client/registry_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('fr.epita.p2pchat/secure_enclave_signing');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'app identity uses enclave public key and delegates digest signing',
    () async {
      final softwareIdentity = await Identity.generate();
      final agreementSeed = Uint8List(32)..[31] = 1;
      Uint8List? signedDigest;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'createOrLoad':
                return <Object?, Object?>{
                  'publicKey': softwareIdentity.signingPublicKey,
                };
              case 'createOrLoadAgreementKey':
                return agreementSeed;
              case 'signDigest':
                signedDigest = call.arguments as Uint8List;
                return Uint8List(64);
              default:
                return null;
            }
          });

      final identity = await createAppIdentity(signing: SecureEnclaveSigning());
      final signature = await identity.sign(<int>[1, 2, 3]);

      expect(identity.signingPublicKey, softwareIdentity.signingPublicKey);
      expect(identity.agreementPublicKey, hasLength(65));
      expect(signedDigest, hasLength(32));
      expect(signature, hasLength(64));
      await expectLater(identity.toJson(), throwsA(isA<ProtocolException>()));
    },
  );

  test('app identity reports a native key replacement', () async {
    final softwareIdentity = await Identity.generate();
    var keyChanged = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'createOrLoad':
              return <Object?, Object?>{
                'publicKey': softwareIdentity.signingPublicKey,
                'keyChanged': true,
              };
            case 'createOrLoadAgreementKey':
              return <Object?, Object?>{
                'agreementKey': Uint8List(32)..[31] = 1,
                'keyChanged': false,
              };
            default:
              return null;
          }
        });

    await createAppIdentity(
      signing: SecureEnclaveSigning(),
      onKeyChanged: () => keyChanged = true,
    );

    expect(keyChanged, isTrue);
  });
}
