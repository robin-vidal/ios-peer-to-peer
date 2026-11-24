# p2pchat

Flutter app for the peer to peer chat. iOS is the target. Android and macOS
build for development and for the demo second device.

The long term signing key is hardware-backed: it lives in the Secure Enclave
on iOS and Android Keystore on Android. There is no software signing-key
fallback. If hardware-backed P-256 signing is unavailable, identity
initialization fails explicitly. Android is a supported development target;
macOS builds are for development and do not provide identity support.

Both supported mobile platforms obtain signing operations through their native
key store; the signing private key is never serialized into Dart or app
preferences. The agreement key remains software-backed and is persisted by the
native platform plugin. The app checks hardware availability, initializes the
identity at launch, and displays initialization errors.

Protocol and server: [docs/protocol.md](../docs/protocol.md). Dart SDK:
[client](../client).

```sh
flutter analyze
flutter test
flutter run
```
