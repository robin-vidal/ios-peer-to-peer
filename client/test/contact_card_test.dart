import 'package:registry_client/registry_client.dart';
import 'package:test/test.dart';

void main() {
  test('a card round trips through its encoded form', () async {
    final identity = await Identity.generate();
    final decoded = await ContactCard.decode(identity.card.encode());

    expect(decoded.id, identity.id);
    expect(decoded.signingPublicKey, identity.signingPublicKey);
    expect(decoded.agreementPublicKey, identity.agreementPublicKey);
    expect(decoded, identity.card);
  });

  test('the id is derived from the keys, never read from the card', () async {
    final identity = await Identity.generate();
    final encoded = identity.card.encode();

    expect(encoded.contains(identity.id), isFalse);
    expect((await ContactCard.decode(encoded)).id, identity.id);
  });

  test('the short fingerprint is the first 8 characters of the id', () async {
    final identity = await Identity.generate();

    expect(identity.card.shortFingerprint, identity.id.substring(0, 8));
  });

  test('malformed cards are rejected', () async {
    final valid = (await Identity.generate()).card.encode();
    final parts = valid.split(':');

    final cases = <String>[
      '',
      'nope:2:${parts[2]}:${parts[3]}',
      'p2pchat:1:${parts[2]}:${parts[3]}',
      'p2pchat:3:${parts[2]}:${parts[3]}',
      'p2pchat:2:${parts[2]}',
      'p2pchat:2:!!!:${parts[3]}',
      'p2pchat:2:${parts[2]}:AAAA',
    ];

    for (final broken in cases) {
      expect(
        () => ContactCard.decode(broken),
        throwsA(isA<ProtocolException>()),
        reason: 'should reject "$broken"',
      );
    }
  });
}
