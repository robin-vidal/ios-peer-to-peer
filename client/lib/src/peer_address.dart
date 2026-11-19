import 'exceptions.dart';

class PeerAddress {
  const PeerAddress({required this.host, required this.port});

  final String host;
  final int port;

  void validate() {
    if (host.isEmpty || host.length > 255) {
      throw const ProtocolException('host must be 1 to 255 characters');
    }
    if (port < 1 || port > 65535) {
      throw const ProtocolException('port must be 1 to 65535');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PeerAddress && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => '$host:$port';
}

class SignedPeerAddress {
  const SignedPeerAddress({required this.address, required this.publishedAt});

  final PeerAddress address;
  final DateTime publishedAt;

  @override
  String toString() => '$address at ${publishedAt.toIso8601String()}';
}
