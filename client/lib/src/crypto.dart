import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'exceptions.dart';

const int publicKeyLength = 65;
const int scalarLength = 32;
const int signatureLength = 64;
const int gcmTagLength = 16;

const int _gcmNonceLength = 12;
const int _uncompressedPrefix = 0x04;

final ECDomainParameters p256 = ECDomainParameters('prime256v1');

SecureRandom newSecureRandom() {
  final entropy = Random.secure();
  final seed = Uint8List.fromList(
    List<int>.generate(32, (_) => entropy.nextInt(256)),
  );
  return FortunaRandom()..seed(KeyParameter(seed));
}

Uint8List sha256Of(List<int> data) =>
    SHA256Digest().process(Uint8List.fromList(data));

Uint8List scalarToBytes(BigInt scalar) {
  final out = Uint8List(scalarLength);
  var remaining = scalar;
  for (var index = scalarLength - 1; index >= 0; index--) {
    out[index] = (remaining & BigInt.from(0xff)).toInt();
    remaining = remaining >> 8;
  }
  return out;
}

BigInt bytesToScalar(List<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}

AsymmetricKeyPair<ECPublicKey, ECPrivateKey> generateKeyPair() {
  final generator = ECKeyGenerator()
    ..init(
      ParametersWithRandom(
        ECKeyGeneratorParameters(p256),
        newSecureRandom(),
      ),
    );
  return generator.generateKeyPair();
}

ECPrivateKey privateKeyFromScalar(List<int> bytes) {
  if (bytes.length != scalarLength) {
    throw const ProtocolException('a private scalar must be 32 bytes');
  }
  final scalar = bytesToScalar(bytes);
  if (scalar < BigInt.one || scalar >= p256.n) {
    throw const ProtocolException(
      'a private scalar must be between 1 and the curve order',
    );
  }
  return ECPrivateKey(scalar, p256);
}

ECPublicKey publicKeyOf(ECPrivateKey key) =>
    ECPublicKey(p256.G * key.d, p256);

Uint8List encodePublicKey(ECPublicKey key) => key.Q!.getEncoded(false);

ECPublicKey decodePublicKey(List<int> bytes) {
  if (bytes.length != publicKeyLength || bytes[0] != _uncompressedPrefix) {
    throw const ProtocolException(
      'a public key must be 65 bytes starting with 0x04',
    );
  }

  ECPoint? point;
  try {
    point = p256.curve.decodePoint(bytes);
  } on Object {
    point = null;
  }

  if (point == null || point.isInfinity || !_isOnCurve(point)) {
    throw const ProtocolException('a public key is not a point on P-256');
  }

  final canonical = point.getEncoded(false);
  if (canonical.length != bytes.length) {
    throw const ProtocolException('a public key is not canonically encoded');
  }
  for (var index = 0; index < canonical.length; index++) {
    if (canonical[index] != bytes[index]) {
      throw const ProtocolException('a public key is not canonically encoded');
    }
  }

  return ECPublicKey(point, p256);
}

bool _isOnCurve(ECPoint point) {
  final x = point.x;
  final y = point.y;
  if (x == null || y == null) {
    return false;
  }
  final curve = point.curve;
  final left = y.square().toBigInteger();
  final right = (x.square() * x + curve.a! * x + curve.b!).toBigInteger();
  return left == right;
}

Uint8List signMessage({
  required ECPrivateKey key,
  required List<int> message,
}) {
  final signer = ECDSASigner(null, HMac(SHA256Digest(), 64))
    ..init(
      true,
      ParametersWithRandom(
        PrivateKeyParameter<ECPrivateKey>(key),
        newSecureRandom(),
      ),
    );

  final signature = signer.generateSignature(sha256Of(message)) as ECSignature;

  return Uint8List(signatureLength)
    ..setRange(0, scalarLength, scalarToBytes(signature.r))
    ..setRange(scalarLength, signatureLength, scalarToBytes(signature.s));
}

bool verifyMessage({
  required ECPublicKey key,
  required List<int> message,
  required List<int> signature,
}) {
  if (signature.length != signatureLength) {
    return false;
  }

  final r = bytesToScalar(signature.sublist(0, scalarLength));
  final s = bytesToScalar(signature.sublist(scalarLength));
  if (r < BigInt.one || r >= p256.n || s < BigInt.one || s >= p256.n) {
    return false;
  }

  final verifier = ECDSASigner(null, HMac(SHA256Digest(), 64))
    ..init(false, PublicKeyParameter<ECPublicKey>(key));
  return verifier.verifySignature(sha256Of(message), ECSignature(r, s));
}

Uint8List agreedSecret({
  required ECPrivateKey key,
  required ECPublicKey peer,
}) {
  final agreement = ECDHBasicAgreement()..init(key);
  return scalarToBytes(agreement.calculateAgreement(peer));
}

Uint8List hkdfSha256({
  required List<int> secret,
  required List<int> salt,
  required List<int> info,
  int length = 32,
}) {
  final kdf = HKDFKeyDerivator(SHA256Digest())
    ..init(
      HkdfParameters(
        Uint8List.fromList(secret),
        length,
        Uint8List.fromList(salt),
        Uint8List.fromList(info),
      ),
    );
  return kdf.process(Uint8List(0));
}

Uint8List aesGcmSeal({
  required List<int> key,
  required List<int> plaintext,
}) =>
    _aesGcm(forEncryption: true, key: key, input: plaintext);

Uint8List aesGcmOpen({
  required List<int> key,
  required List<int> ciphertext,
}) =>
    _aesGcm(forEncryption: false, key: key, input: ciphertext);

Uint8List _aesGcm({
  required bool forEncryption,
  required List<int> key,
  required List<int> input,
}) {
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      forEncryption,
      AEADParameters(
        KeyParameter(Uint8List.fromList(key)),
        gcmTagLength * 8,
        Uint8List(_gcmNonceLength),
        Uint8List(0),
      ),
    );
  return cipher.process(Uint8List.fromList(input));
}
