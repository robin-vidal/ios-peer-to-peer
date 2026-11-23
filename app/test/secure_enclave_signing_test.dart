import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:p2pchat/secure_enclave_signing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureEnclaveSigning', () {
    const channelName = 'fr.epita.p2pchat/secure_enclave_signing';
    const messengerChannel = MethodChannel(channelName);

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(messengerChannel, null);
    });

    test('createOrLoad accepts a 65-byte x963 public key', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel(channelName), (
        call,
      ) async {
        if (call.method == 'createOrLoad') {
          return <Object?, Object?>{
            'publicKey': Uint8List.fromList(
              List<int>.filled(65, 0)..[0] = 0x04,
            ),
          };
        }
        return null;
      });

      final publicKey = await SecureEnclaveSigning().createOrLoad();

      expect(publicKey, hasLength(65));
      expect(publicKey.first, 0x04);
    });

    test('createOrLoad rejects a malformed public key', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel(channelName),
        (call) async => <Object?, Object?>{
          'publicKey': Uint8List.fromList(List<int>.filled(64, 0)),
        },
      );

      await expectLater(
        SecureEnclaveSigning().createOrLoad(),
        throwsA(
          isA<SecureEnclaveSigningException>().having(
            (error) => error.code,
            'code',
            'invalid-public-key',
          ),
        ),
      );
    });

    test('signDigest rejects a digest that is not 32 bytes', () async {
      await expectLater(
        SecureEnclaveSigning().signDigest(Uint8List(31)),
        throwsA(
          isA<SecureEnclaveSigningException>().having(
            (error) => error.code,
            'code',
            'invalid-digest',
          ),
        ),
      );
    });

    test('signDigest returns exactly 64 signature bytes', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel(channelName),
        (call) async => Uint8List.fromList(List<int>.filled(64, 0xA5)),
      );

      final signature = await SecureEnclaveSigning().signDigest(Uint8List(32));

      expect(signature, hasLength(64));
      expect(signature.every((byte) => byte == 0xA5), isTrue);
    });

    test('native PlatformException codes remain distinguishable', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel(channelName),
        (call) async => throw PlatformException(
          code: 'key-creation-failed',
          message: 'creation failed',
        ),
      );

      await expectLater(
        SecureEnclaveSigning().createOrLoad(),
        throwsA(
          isA<SecureEnclaveSigningException>().having(
            (error) => error.code,
            'code',
            'key-creation-failed',
          ),
        ),
      );
    });
  });
}
