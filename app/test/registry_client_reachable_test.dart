import 'package:flutter_test/flutter_test.dart';
import 'package:registry_client/registry_client.dart';

void main() {
  test('the registry client package is reachable from app code', () async {
    final identity = await Identity.generate();

    expect(identity.id, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(await ContactCard.decode(identity.card.encode()), identity.card);
  });
}
