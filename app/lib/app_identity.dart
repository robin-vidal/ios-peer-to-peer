import 'package:registry_client/registry_client.dart';

import 'secure_enclave_signing.dart';

Future<Identity> createAppIdentity({
  SecureEnclaveSigning? signing,
}) async {
  final secureSigning = signing ?? SecureEnclaveSigning();
  final signingPublicKey = await secureSigning.createOrLoad();
  final agreementSeed = await secureSigning.createOrLoadAgreementKey();

  return Identity.fromExternalSigner(
    signingPublicKey: signingPublicKey,
    agreementSeed: agreementSeed,
    signDigest: secureSigning.signDigest,
  );
}
