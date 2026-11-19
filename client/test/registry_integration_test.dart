import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:registry_client/registry_client.dart';
import 'package:test/test.dart';

const String _serverPath = '../registry-server';

bool _hasTool(String executable, List<String> args) {
  try {
    return Process.runSync(executable, args).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

String? _missingRequirement() {
  if (!Directory(_serverPath).existsSync()) {
    return 'the Go server is not at $_serverPath';
  }
  if (!_hasTool('go', <String>['version'])) {
    return 'the go toolchain is not available';
  }
  if (!_hasTool('openssl', <String>['version'])) {
    return 'openssl is not available';
  }
  return null;
}

void main() {
  final missing = _missingRequirement();

  group('against a live registry server', () {
    late Directory workDir;
    late Process server;
    late int port;
    late String fingerprint;

    setUpAll(() async {
      workDir = await Directory.systemTemp.createTemp('registry-client-it');

      final certPath = '${workDir.path}/server.crt';
      final keyPath = '${workDir.path}/server.key';

      final cert = await Process.run('openssl', <String>[
        'req',
        '-x509',
        '-newkey',
        'ec',
        '-pkeyopt',
        'ec_paramgen_curve:prime256v1',
        '-keyout',
        keyPath,
        '-out',
        certPath,
        '-days',
        '1',
        '-nodes',
        '-subj',
        '/CN=registry-client-test',
        '-addext',
        'subjectAltName=IP:127.0.0.1',
      ]);
      expect(cert.exitCode, 0, reason: 'openssl failed: ${cert.stderr}');

      final digest = await Process.run('openssl', <String>[
        'x509',
        '-in',
        certPath,
        '-noout',
        '-fingerprint',
        '-sha256',
      ]);
      expect(digest.exitCode, 0, reason: 'openssl failed: ${digest.stderr}');
      fingerprint = (digest.stdout as String).trim().split('=').last;

      final binary = '${workDir.path}/registry-server';
      final build = await Process.run(
        'go',
        <String>['build', '-o', binary, '.'],
        workingDirectory: _serverPath,
      );
      expect(build.exitCode, 0, reason: 'go build failed: ${build.stderr}');

      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      port = probe.port;
      await probe.close();

      server = await Process.start(
        binary,
        <String>[],
        environment: <String, String>{
          'REGISTRY_ADDR': '127.0.0.1:$port',
          'REGISTRY_TLS_CERT': certPath,
          'REGISTRY_TLS_KEY': keyPath,
        },
      );

      final listening = Completer<void>();
      server.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((String line) {
        if (line.contains('listening') && !listening.isCompleted) {
          listening.complete();
        }
      });
      server.stderr.drain<void>();

      await listening.future.timeout(const Duration(seconds: 20));
    });

    tearDownAll(() async {
      server.kill(ProcessSignal.sigkill);
      await server.exitCode;
      await workDir.delete(recursive: true);
    });

    Future<RegistryClient> connectAs(Identity identity) {
      return RegistryClient.connect(
        host: '127.0.0.1',
        port: port,
        pinnedSha256: fingerprint,
        identity: identity,
      );
    }

    test('the server derives the same id as the client', () async {
      final identity = await Identity.generate();
      final client = await connectAs(identity);

      expect(client.myId, identity.id);

      await client.close();
    });

    test('a certificate that does not match the pin is refused', () async {
      final identity = await Identity.generate();

      await expectLater(
        RegistryClient.connect(
          host: '127.0.0.1',
          port: port,
          pinnedSha256: '0' * 64,
          identity: identity,
        ),
        throwsA(isA<CertificatePinException>()),
      );
    });

    test('a contact fetches the address published for it', () async {
      final alice = await Identity.generate();
      final bob = await Identity.generate();
      const address = PeerAddress(host: '10.0.0.7', port: 9100);

      final aliceClient = await connectAs(alice);
      final bobClient = await connectAs(bob);

      await aliceClient.publishAddress(to: bob.card, address: address);

      final fetched = await bobClient.fetchAddress(of: alice.card);
      expect(fetched, isNotNull);
      expect(fetched!.address, address);

      await bobClient.close();
      await aliceClient.close();
    });

    test('a peer with no blob published for it gets nothing', () async {
      final alice = await Identity.generate();
      final bob = await Identity.generate();
      final carol = await Identity.generate();

      final aliceClient = await connectAs(alice);
      final carolClient = await connectAs(carol);

      await aliceClient.publishAddress(
        to: bob.card,
        address: const PeerAddress(host: '10.0.0.8', port: 9200),
      );

      expect(await carolClient.fetchAddress(of: alice.card), isNull);

      await carolClient.close();
      await aliceClient.close();
    });

    test('an unknown owner yields nothing', () async {
      final bob = await Identity.generate();
      final stranger = await Identity.generate();

      final bobClient = await connectAs(bob);
      expect(await bobClient.fetchAddress(of: stranger.card), isNull);

      await bobClient.close();
    });

    test('blobs vanish when the publisher disconnects', () async {
      final alice = await Identity.generate();
      final bob = await Identity.generate();

      final aliceClient = await connectAs(alice);
      final bobClient = await connectAs(bob);

      await aliceClient.publishAddress(
        to: bob.card,
        address: const PeerAddress(host: '10.0.0.9', port: 9300),
      );
      expect(await bobClient.fetchAddress(of: alice.card), isNotNull);

      await aliceClient.close();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(await bobClient.fetchAddress(of: alice.card), isNull);

      await bobClient.close();
    });

    test('republishing replaces the previous address', () async {
      final alice = await Identity.generate();
      final bob = await Identity.generate();

      final aliceClient = await connectAs(alice);
      final bobClient = await connectAs(bob);

      await aliceClient.publishAddress(
        to: bob.card,
        address: const PeerAddress(host: '10.0.0.10', port: 9400),
      );
      await aliceClient.publishAddress(
        to: bob.card,
        address: const PeerAddress(host: '10.0.0.11', port: 9500),
      );

      final fetched = await bobClient.fetchAddress(of: alice.card);
      expect(fetched!.address, const PeerAddress(host: '10.0.0.11', port: 9500));

      await bobClient.close();
      await aliceClient.close();
    });

    test('exceeding the recipient cap raises a typed error', () async {
      final alice = await Identity.generate();
      final aliceClient = await connectAs(alice);

      Future<void> publishTo(Identity recipient) => aliceClient.publishAddress(
            to: recipient.card,
            address: const PeerAddress(host: '10.0.0.12', port: 9600),
          );

      for (var i = 0; i < 64; i++) {
        await publishTo(await Identity.generate());
      }

      await expectLater(
        publishTo(await Identity.generate()),
        throwsA(isA<TooManyRecipientsException>()),
      );

      await aliceClient.close();
    });
  }, skip: missing);
}
