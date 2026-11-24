import 'package:flutter/services.dart';

class SecureEnclaveSigningException implements Exception {
  const SecureEnclaveSigningException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'SecureEnclaveSigningException($code): $message';
}

class SecureEnclaveSigning {
  SecureEnclaveSigning({MethodChannel? channel})
      : _channel = channel ??
            const MethodChannel(
              'fr.epita.p2pchat/secure_enclave_signing',
            );

  final MethodChannel _channel;
  bool keyChanged = false;

  Future<bool> get isAvailable async {
    final value = await _invoke('isAvailable');
    if (value is! bool) {
      throw const SecureEnclaveSigningException(
        'invalid-native-result',
        'The native plugin returned an invalid availability result.',
      );
    }
    return value;
  }

  Future<Uint8List> createOrLoad() async {
    final result = await _invokeMap('createOrLoad');
    keyChanged = keyChanged || result['keyChanged'] == true;
    return _publicKey(result['publicKey']);
  }

  Future<Uint8List> getPublicKey() async {
    return _publicKey(await _invoke('getPublicKey'));
  }

  Future<Uint8List> createOrLoadAgreementKey() async {
    final nativeResult = await _invoke('createOrLoadAgreementKey');
    Object? value = nativeResult;
    if (nativeResult is Map) {
      final result = nativeResult.cast<Object?, Object?>();
      keyChanged = keyChanged || result['keyChanged'] == true;
      value = result['agreementKey'];
    }
    if (value is! Uint8List && value is! List<int>) {
      throw const SecureEnclaveSigningException(
        'invalid-agreement-key',
        'The native plugin returned no agreement key.',
      );
    }

    final key = Uint8List.fromList(value as List<int>);
    if (key.length != 32) {
      throw SecureEnclaveSigningException(
        'invalid-agreement-key',
        'The agreement key must be exactly 32 bytes, got ${key.length}.',
      );
    }
    return key;
  }

  Future<Uint8List> signDigest(Uint8List digest) async {
    if (digest.length != 32) {
      throw const SecureEnclaveSigningException(
        'invalid-digest',
        'The signing digest must be exactly 32 bytes.',
      );
    }

    final signature = await _invoke('signDigest', digest);
    if (signature is! Uint8List && signature is! List<int>) {
      throw const SecureEnclaveSigningException(
        'invalid-signature',
        'The native plugin returned no signature.',
      );
    }

    final bytes = Uint8List.fromList(signature as List<int>);
    if (bytes.length != 64) {
      throw SecureEnclaveSigningException(
        'invalid-signature',
        'The signing signature must be exactly 64 bytes, got ${bytes.length}.',
      );
    }
    return bytes;
  }

  Future<void> deleteIdentity() async {
    await _invoke('deleteIdentity');
  }

  Uint8List _publicKey(Object? value) {
    if (value is! Uint8List && value is! List<int>) {
      throw const SecureEnclaveSigningException(
        'invalid-public-key',
        'The native plugin returned no public key.',
      );
    }

    final bytes = Uint8List.fromList(value as List<int>);
    if (bytes.length != 65 || bytes.first != 0x04) {
      throw const SecureEnclaveSigningException(
        'invalid-public-key',
        'The public key must be 65 x963 bytes starting with 0x04.',
      );
    }
    return bytes;
  }

  Future<Object?> _invoke(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException catch (error) {
      throw SecureEnclaveSigningException(
        'native-plugin-unavailable',
        'The native identity plugin is unavailable on this platform: ${error.message ?? method}.',
      );
    } on PlatformException catch (error) {
      throw SecureEnclaveSigningException(
        error.code,
        error.message ?? 'The native hardware-backed signing operation failed.',
      );
    }
  }

  Future<Map<Object?, Object?>> _invokeMap(String method) async {
    final result = await _invoke(method);
    if (result is! Map) {
      throw const SecureEnclaveSigningException(
        'invalid-native-result',
        'The native plugin returned an invalid result.',
      );
    }
    return result.cast<Object?, Object?>();
  }
}
