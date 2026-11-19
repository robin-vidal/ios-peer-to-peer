import 'dart:convert';
import 'dart:typed_data';

import 'codec.dart';
import 'exceptions.dart';
import 'identity.dart';

class ContactCard {
  const ContactCard({
    required this.signingPublicKey,
    required this.agreementPublicKey,
    required this.id,
  });

  final Uint8List signingPublicKey;
  final Uint8List agreementPublicKey;
  final String id;

  String get shortFingerprint => id.substring(0, 8);

  String encode() {
    final signing = base64Url.encode(signingPublicKey);
    final agreement = base64Url.encode(agreementPublicKey);
    return 'p2pchat:1:$signing:$agreement';
  }

  static Future<ContactCard> decode(String text) async {
    final parts = text.split(':');
    if (parts.length != 4 || parts[0] != 'p2pchat' || parts[1] != '1') {
      throw const ProtocolException('not a version 1 contact card');
    }

    final Uint8List signingPublicKey;
    final Uint8List agreementPublicKey;
    try {
      signingPublicKey = base64Url.decode(parts[2]);
      agreementPublicKey = base64Url.decode(parts[3]);
    } on FormatException {
      throw const ProtocolException('contact card holds invalid base64');
    }

    if (signingPublicKey.length != keyLength ||
        agreementPublicKey.length != keyLength) {
      throw const ProtocolException('a contact card key is not 32 bytes');
    }

    return ContactCard(
      signingPublicKey: signingPublicKey,
      agreementPublicKey: agreementPublicKey,
      id: await Identity.deriveId(
        signingPublicKey: signingPublicKey,
        agreementPublicKey: agreementPublicKey,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ContactCard &&
      other.id == id &&
      constantTimeEquals(other.signingPublicKey, signingPublicKey) &&
      constantTimeEquals(other.agreementPublicKey, agreementPublicKey);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ContactCard($shortFingerprint)';
}
