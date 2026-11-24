import 'package:registry_client/registry_client.dart';

import 'secure_enclave_signing.dart';

Future<Identity> createAppIdentity({
  SecureEnclaveSigning? signing,
  void Function()? onKeyChanged,
}) async {
  final secureSigning = signing ?? SecureEnclaveSigning();
  secureSigning.keyChanged = false;
  if (!await secureSigning.isAvailable) {
    throw const SecureEnclaveSigningException(
      'secure-hardware-unavailable',
      'A hardware-backed P-256 signing key is not available on this device.',
    );
  }
  final signingPublicKey = await secureSigning.createOrLoad();
  final agreementSeed = await secureSigning.createOrLoadAgreementKey();
  if (secureSigning.keyChanged) {
    onKeyChanged?.call();
  }

  return Identity.fromExternalSigner(
    signingPublicKey: signingPublicKey,
    agreementSeed: agreementSeed,
    signDigest: secureSigning.signDigest,
  );
}
