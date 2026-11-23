# p2pchat

Flutter app for the peer to peer chat. iOS is the target. Android and macOS
build for development and for the demo second device.

The long term signing key lives in the Secure Enclave on iOS. Android has no
enclave, so an Android build falls back to a software identity, which is a
debug only path and never a graded target.

The iOS app obtains its signing key through the native Secure Enclave channel.
The agreement key is software-backed and persisted in the device-only Keychain;
the signing private key is never serialized into Dart or app preferences.
The app initializes this identity at launch and displays initialization errors.

Protocol and server: [docs/protocol.md](../docs/protocol.md). Dart SDK:
[client](../client).

```sh
flutter analyze
flutter test
flutter run
```
