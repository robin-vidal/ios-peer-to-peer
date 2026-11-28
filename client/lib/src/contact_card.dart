import 'dart:convert';
import 'dart:typed_data';

import 'codec.dart';
import 'crypto.dart';
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
    return 'p2pchat:2:$signing:$agreement';
  }

  static Future<ContactCard> decode(String text) async {
    final parts = text.split(':');
    if (parts.length != 4 || parts[0] != 'p2pchat' || parts[1] != '2') {
      throw const ProtocolException('not a version 2 contact card');
    }

    final Uint8List signingPublicKey;
    final Uint8List agreementPublicKey;
    try {
      signingPublicKey = base64Url.decode(parts[2]);
      agreementPublicKey = base64Url.decode(parts[3]);
    } on FormatException {
      throw const ProtocolException('contact card holds invalid base64');
    }

    decodePublicKey(signingPublicKey);
    decodePublicKey(agreementPublicKey);

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

  factory ContactCard.fromDB(String row) {
    final agreementKey = Uint8List.fromList(row.substring(0, 65).codeUnits);
    final signKey = Uint8List.fromList(row.substring(65).codeUnits);
    final id = hexEncode(sha256Of(<int>[
      ...signKey,
      ...agreementKey,
    ]));
    return ContactCard(
        signingPublicKey: signKey, agreementPublicKey: agreementKey, id: id);
  }

  String toDB() {
    return String.fromCharCodes(agreementPublicKey + signingPublicKey);
  }
}
