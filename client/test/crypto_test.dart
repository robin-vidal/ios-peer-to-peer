import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart' show InvalidCipherTextException;
import 'package:registry_client/src/crypto.dart';
import 'package:test/test.dart';

void main() {
  final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
  final nonce = Uint8List.fromList(
    <int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7],
  );
  final header = Uint8List.fromList(<int>[1, 2, 0, 0, 0, 0, 0, 42]);
  final plaintext = utf8.encode('hello');

  test('a non zero nonce and associated data round trip', () {
    final sealed = aesGcmSeal(
      key: key,
      nonce: nonce,
      associatedData: header,
      plaintext: plaintext,
    );

    expect(sealed, hasLength(plaintext.length + gcmTagLength));
    expect(
      aesGcmOpen(
        key: key,
        nonce: nonce,
        associatedData: header,
        ciphertext: sealed,
      ),
      plaintext,
    );
  });

  test('a zero nonce and empty associated data still round trip', () {
    final zeroNonce = Uint8List(gcmNonceLength);
    final noData = Uint8List(0);

    final sealed = aesGcmSeal(
      key: key,
      nonce: zeroNonce,
      associatedData: noData,
      plaintext: plaintext,
    );

    expect(
      aesGcmOpen(
        key: key,
        nonce: zeroNonce,
        associatedData: noData,
        ciphertext: sealed,
      ),
      plaintext,
    );
  });

  test('the tag fails when the associated data differs', () {
    final sealed = aesGcmSeal(
      key: key,
      nonce: nonce,
      associatedData: header,
      plaintext: plaintext,
    );

    final edited = Uint8List.fromList(header)..[7] = 43;

    expect(
      () => aesGcmOpen(
        key: key,
        nonce: nonce,
        associatedData: edited,
        ciphertext: sealed,
      ),
      throwsA(isA<InvalidCipherTextException>()),
    );
  });

  test('the tag fails when the nonce differs', () {
    final sealed = aesGcmSeal(
      key: key,
      nonce: nonce,
      associatedData: header,
      plaintext: plaintext,
    );

    final other = Uint8List.fromList(nonce)..[11] = 8;

    expect(
      () => aesGcmOpen(
        key: key,
        nonce: other,
        associatedData: header,
        ciphertext: sealed,
      ),
      throwsA(isA<InvalidCipherTextException>()),
    );
  });

  test('a nonce of the wrong length is refused', () {
    for (final length in <int>[0, 8, 11, 13, 16]) {
      final wrong = Uint8List(length);

      expect(
        () => aesGcmSeal(
          key: key,
          nonce: wrong,
          associatedData: header,
          plaintext: plaintext,
        ),
        throwsArgumentError,
        reason: 'seal accepted a $length byte nonce',
      );
      expect(
        () => aesGcmOpen(
          key: key,
          nonce: wrong,
          associatedData: header,
          ciphertext: Uint8List(gcmTagLength),
        ),
        throwsArgumentError,
        reason: 'open accepted a $length byte nonce',
      );
    }
  });
}