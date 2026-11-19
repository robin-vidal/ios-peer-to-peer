import 'dart:convert';

import 'package:registry_client/registry_client.dart';
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
}
