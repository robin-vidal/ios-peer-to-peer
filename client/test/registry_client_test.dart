import 'package:registry_client/registry_client.dart';
import 'package:registry_client/src/registry_client.dart';
import 'package:test/test.dart';

void main() {
  test('a valid base64 field decodes', () {
    expect(decodeBase64Field('AQID', name: 'blob'), <int>[1, 2, 3]);
  });

  test('a malformed base64 field is a ProtocolException', () {
    for (final text in <String>['not base64!', '****']) {
      expect(
        () => decodeBase64Field(text, name: 'blob'),
        throwsA(isA<ProtocolException>()),
        reason: '"$text" was not refused',
      );
    }
  });

  test('a malformed base64 refusal is a RegistryException', () {
    expect(
      () => decodeBase64Field('not base64!', name: 'challenge'),
      throwsA(isA<RegistryException>()),
    );
  });
}
