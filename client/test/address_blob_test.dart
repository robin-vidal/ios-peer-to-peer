import 'dart:convert';
import 'dart:typed_data';

import 'package:registry_client/registry_client.dart';
import 'package:registry_client/src/codec.dart';
import 'package:registry_client/src/crypto.dart';
import 'package:test/test.dart';

void main() {
  const address = PeerAddress(host: '192.168.1.42', port: 9000);

  test('the intended recipient opens the address', () async {
    final alice = await Identity.generate();
    final bob = await Identity.generate();

    final blob = await AddressBlob.seal(
      author: alice,
      recipient: bob.card,
      address: address,
    );

    final opened = await AddressBlob.open(
      recipient: bob,
      author: alice.card,
      blob: blob,
    );

    expect(opened.address, address);
    expect(
      DateTime.now().toUtc().difference(opened.publishedAt).inSeconds,
      lessThan(5),
    );
  });

  test('a blob fits well inside the server size cap', () async {
    final alice = await Identity.generate();
    final bob = await Identity.generate();

    final blob = await AddressBlob.seal(
      author: alice,
      recipient: bob.card,
      address: const PeerAddress(host: 'a-fairly-long-hostname.example.com', port: 65535),
    );

    expect(base64.encode(blob).length, lessThan(1024));
  });

  test('another identity cannot open the blob', () async {
    final alice = await Identity.generate();
    final bob = await Identity.generate();
    final carol = await Identity.generate();

    final blob = await AddressBlob.seal(
      author: alice,
      recipient: bob.card,
      address: address,
    );

    expect(
      () => AddressBlob.open(recipient: carol, author: alice.card, blob: blob),
      throwsA(isA<BlobAuthenticityException>()),
    );
  });

  test('a blob attributed to the wrong author is rejected', () async {
    final alice = await Identity.generate();
    final bob = await Identity.generate();
    final mallory = await Identity.generate();

    final blob = await AddressBlob.seal(
      author: alice,
      recipient: bob.card,
      address: address,
    );

    expect(
      () => AddressBlob.open(recipient: bob, author: mallory.card, blob: blob),
      throwsA(isA<BlobAuthenticityException>()),
    );
  });

  test('a stale address is rejected', () async {
    final alice = await Identity.generate();
    final bob = await Identity.generate();

    final blob = await AddressBlob.seal(
      author: alice,
      recipient: bob.card,
      address: address,
      publishedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
    );

    expect(
      () => AddressBlob.open(recipient: bob, author: alice.card, blob: blob),
      throwsA(isA<BlobStaleException>()),
    );
  });

  test('an address stamped in the future is rejected', () async {
    final alice = await Identity.generate();
    final bob = await Identity.generate();

    final blob = await AddressBlob.seal(
      author: alice,
      recipient: bob.card,
      address: address,
      publishedAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );

    expect(
      () => AddressBlob.open(recipient: bob, author: alice.card, blob: blob),
      throwsA(isA<BlobStaleException>()),
    );
  });

  test('a truncated blob is rejected', () async {
    final alice = await Identity.generate();
    final bob = await Identity.generate();

    final blob = await AddressBlob.seal(
      author: alice,
      recipient: bob.card,
      address: address,
    );

    expect(
      () => AddressBlob.open(
        recipient: bob,
        author: alice.card,
        blob: blob.sublist(0, 20),
      ),
      throwsA(isA<ProtocolException>()),
    );
  });

  test('a flipped byte breaks authentication', () async {
    final alice = await Identity.generate();
    final bob = await Identity.generate();

    final blob = await AddressBlob.seal(
      author: alice,
      recipient: bob.card,
      address: address,
    );
    blob[blob.length - 1] ^= 0xff;

    expect(
      () => AddressBlob.open(recipient: bob, author: alice.card, blob: blob),
      throwsA(isA<BlobAuthenticityException>()),
    );
  });

  test('an invalid address is refused at seal time', () async {
    final alice = await Identity.generate();
    final bob = await Identity.generate();

    expect(
      () => AddressBlob.seal(
        author: alice,
        recipient: bob.card,
        address: const PeerAddress(host: '', port: 9000),
      ),
      throwsA(isA<ProtocolException>()),
    );
    expect(
      () => AddressBlob.seal(
        author: alice,
        recipient: bob.card,
        address: const PeerAddress(host: 'host', port: 0),
      ),
      throwsA(isA<ProtocolException>()),
    );
  });

  test('an out of range timestamp is refused instead of crashing', () async {
    final alice = await Identity.generate();
    final bob = await Identity.generate();

    for (final milliseconds in <int>[9000000000000000, -9000000000000000]) {
      final blob = await _sealInner(
        author: alice,
        recipient: bob,
        host: utf8.encode('192.168.1.42'),
        milliseconds: milliseconds,
      );

      await expectLater(
        AddressBlob.open(recipient: bob, author: alice.card, blob: blob),
        throwsA(isA<ProtocolException>()),
        reason: 'timestamp $milliseconds was not refused',
      );
    }
  });

  test('a host that is not valid UTF-8 is refused instead of crashing',
      () async {
    final alice = await Identity.generate();
    final bob = await Identity.generate();

    final blob = await _sealInner(
      author: alice,
      recipient: bob,
      host: <int>[0xff, 0xfe],
      milliseconds: DateTime.now().toUtc().millisecondsSinceEpoch,
    );

    await expectLater(
      AddressBlob.open(recipient: bob, author: alice.card, blob: blob),
      throwsA(isA<ProtocolException>()),
    );
  });

  test('every hostile field refusal is a RegistryException', () async {
    final alice = await Identity.generate();
    final bob = await Identity.generate();

    final blob = await _sealInner(
      author: alice,
      recipient: bob,
      host: <int>[0xff, 0xfe],
      milliseconds: 9000000000000000,
    );

    await expectLater(
      AddressBlob.open(recipient: bob, author: alice.card, blob: blob),
      throwsA(isA<RegistryException>()),
    );
  });
}

Future<Uint8List> _sealInner({
  required Identity author,
  required Identity recipient,
  required List<int> host,
  required int milliseconds,
}) async {
  final inner = (FieldWriter()
        ..raw(utf8.encode(addressDomain))
        ..field(host)
        ..field(uint16(9000))
        ..field(int64(milliseconds)))
      .take();
  final signature = await author.sign(inner);

  final payload = (FieldWriter()
        ..field(inner)
        ..field(signature))
      .take();

  final ephemeral = generateKeyPair();
  final ephemeralPublicKey = encodePublicKey(ephemeral.publicKey);
  final key = hkdfSha256(
    secret: agreedSecret(
      key: ephemeral.privateKey,
      peer: decodePublicKey(recipient.card.agreementPublicKey),
    ),
    salt: ephemeralPublicKey,
    info: utf8.encode(addressDomain),
  );

  return (FieldWriter()
        ..raw(ephemeralPublicKey)
        ..raw(aesGcmSeal(
          key: key,
          nonce: Uint8List(gcmNonceLength),
          associatedData: Uint8List(0),
          plaintext: payload,
        )))
      .take();
}
