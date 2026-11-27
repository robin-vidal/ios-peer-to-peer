import 'dart:math';

void insecureRandom() {
  // ruleid: dart-insecure-random
  final weak = Random();
  // ruleid: dart-insecure-random
  final seeded = Random(42);
  // ok: dart-insecure-random
  final strong = Random.secure();
}

void weakDigest() {
  // ruleid: dart-weak-digest
  final md5 = MD5Digest();
  // ruleid: dart-weak-digest
  final sha1 = SHA1Digest();
  // ok: dart-weak-digest
  final sha256 = SHA256Digest();
}

void cipherModes(Uint8List key) {
  // ruleid: dart-unauthenticated-cipher-mode
  final ecb = ECBBlockCipher(AESEngine());
  // ruleid: dart-unauthenticated-cipher-mode
  final cbc = CBCBlockCipher(AESEngine());
  // ruleid: dart-gcm-outside-crypto-layer
  final gcm = GCMBlockCipher(AESEngine());
  // ruleid: dart-gcm-outside-crypto-layer
  final params = AEADParameters(KeyParameter(key), 128, Uint8List(12), Uint8List(0));
  // ok: dart-unauthenticated-cipher-mode
  final sealed = aesGcmSeal(key: key, plaintext: key);
}

bool verification(ECPublicKey key, Uint8List message, Uint8List signature, ECSignature sig) {
  // ruleid: dart-signature-result-ignored
  verifyMessage(key: key, message: message, signature: signature);
  // ruleid: dart-signature-result-ignored
  ECDSASigner(null, HMac(SHA256Digest(), 64)).verifySignature(message, sig);
  // ok: dart-signature-result-ignored
  final verified = verifyMessage(key: key, message: message, signature: signature);
  // ok: dart-signature-result-ignored
  if (!verifyMessage(key: key, message: message, signature: signature)) {
    return false;
  }
  return verified;
}

ECPoint? rawPoint(List<int> bytes) {
  // ruleid: dart-raw-point-decode
  return p256.curve.decodePoint(bytes);
}

ECPublicKey checkedPoint(List<int> bytes) {
  // ok: dart-raw-point-decode
  return decodePublicKey(bytes);
}

bool compare(Uint8List a, Uint8List b) {
  // ruleid: dart-non-constant-time-compare
  final early = listEquals(a, b);
  // ruleid: dart-non-constant-time-compare
  final collection = const ListEquality().equals(a, b);
  // ok: dart-non-constant-time-compare
  return constantTimeEquals(a, b);
}

Future<void> logging(Identity identity) async {
  // ruleid: dart-private-key-logged
  print(identity.signingKey);
  // ruleid: dart-private-key-logged
  print('seed ${identity.agreementKey.d}');
  // ruleid: dart-private-key-logged
  print(await identity.toJson());
  // ok: dart-private-key-logged
  print(identity.id);
}

Uint8List? swallow(Uint8List key, Uint8List sealed) {
  // ruleid: dart-crypto-exception-swallowed
  try {
    return aesGcmOpen(key: key, ciphertext: sealed);
  } on InvalidCipherTextException {}
  // ok: dart-crypto-exception-swallowed
  try {
    return aesGcmOpen(key: key, ciphertext: sealed);
  } on InvalidCipherTextException {
    throw const BlobAuthenticityException('not sealed for this identity');
  }
}
