import CryptoKit
import Flutter
import Foundation
import Security

final class SecureEnclaveSigningPlugin: NSObject, FlutterPlugin {
  private static let channelName = "fr.epita.p2pchat/secure_enclave_signing"
  private static let signingKeychainAccount = "long-term-p256-signing-key"
  private static let agreementKeychainAccount = "long-term-p256-agreement-key"
  private static let identityBaselineKeychainAccount = "long-term-p256-identity-baseline"
  private static let keychainService = "fr.epita.p2pchat.signing"

  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: channelName) else {
      return
    }
    register(with: registrar)
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = SecureEnclaveSigningPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(SecureEnclave.isAvailable)
    case "createOrLoad":
      createOrLoad(result: result)
    case "getPublicKey":
      loadPublicKey(result: result)
    case "signDigest":
      signDigest(call.arguments, result: result)
    case "createOrLoadAgreementKey":
      createOrLoadAgreementKey(result: result)
    case "deleteIdentity":
      deleteIdentity(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func createOrLoad(result: @escaping FlutterResult) {
    guard SecureEnclave.isAvailable else {
      result(FlutterError(
        code: "secure-enclave-unavailable",
        message: "Secure Enclave is unavailable on this device.",
        details: nil
      ))
      return
    }

    do {
      let key: SecureEnclave.P256.Signing.PrivateKey
      let previousBaseline = try loadValue(account: Self.identityBaselineKeychainAccount)
      var keyChanged = false
      if let stored = try loadValue(account: Self.signingKeychainAccount) {
        if let loaded = try? SecureEnclave.P256.Signing.PrivateKey(
          dataRepresentation: stored
        ) {
          key = loaded
          if let previousBaseline,
             previousBaseline.count >= 65,
             previousBaseline.subdata(in: 0..<65) != key.publicKey.x963Representation {
            keyChanged = true
          }
        } else {
          let deleteStatus = deleteStoredValue(account: Self.signingKeychainAccount)
          guard isDeleted(deleteStatus) else {
            throw SigningPluginError.keychainStatus(deleteStatus)
          }
          if previousBaseline != nil {
            keyChanged = true
          }
          do {
            key = try createPrivateKey()
          } catch {
            result(FlutterError(
              code: "key-creation-failed",
              message: "Secure Enclave key creation failed after the old key became unavailable.",
              details: String(describing: error)
            ))
            return
          }
        }
      } else {
        if previousBaseline != nil {
          keyChanged = true
        }
        do {
          key = try createPrivateKey()
        } catch {
          result(FlutterError(
            code: "key-creation-failed",
            message: "Secure Enclave key creation failed.",
            details: String(describing: error)
          ))
          return
        }
      }

      let publicKey = key.publicKey.x963Representation
      result([
        "publicKey": FlutterStandardTypedData(bytes: publicKey),
        "keyChanged": keyChanged,
      ])
    } catch {
      result(FlutterError(
        code: "key-load-failed",
        message: "The stored signing key could not be accessed.",
        details: String(describing: error)
      ))
    }
  }

  private func createPrivateKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
    var accessControlError: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(
      nil,
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      [.privateKeyUsage],
      &accessControlError
    ) else {
      throw SigningPluginError.accessControlCreation(
        accessControlError?.takeRetainedValue()
      )
    }

    let key = try SecureEnclave.P256.Signing.PrivateKey(
      compactRepresentable: true,
      accessControl: accessControl
    )
    try storeValue(key.dataRepresentation, account: Self.signingKeychainAccount)
    return key
  }

  private func createOrLoadAgreementKey(result: @escaping FlutterResult) {
    do {
      let key: P256.KeyAgreement.PrivateKey
      let previousBaseline = try loadValue(account: Self.identityBaselineKeychainAccount)
      var keyChanged = false
      if let stored = try loadValue(account: Self.agreementKeychainAccount),
         let loaded = try? P256.KeyAgreement.PrivateKey(rawRepresentation: stored) {
        key = loaded
        if let previousBaseline,
           previousBaseline.count == 130,
           previousBaseline.subdata(in: 65..<130) != key.publicKey.x963Representation {
          keyChanged = true
        }
      } else {
        if previousBaseline != nil && previousBaseline!.count == 130 {
          keyChanged = true
        }
        let generated = P256.KeyAgreement.PrivateKey()
        try storeValue(
          generated.rawRepresentation,
          account: Self.agreementKeychainAccount
        )
        key = generated
      }
      guard let signingKey = try loadPrivateKey() else {
        throw SigningPluginError.keyNotFound
      }
      if let previousBaseline,
         previousBaseline.count == 130,
         previousBaseline.subdata(in: 0..<65) != signingKey.publicKey.x963Representation {
        keyChanged = true
      }
      var identityBaseline = signingKey.publicKey.x963Representation
      identityBaseline.append(key.publicKey.x963Representation)
      try storeValue(identityBaseline, account: Self.identityBaselineKeychainAccount)
      result([
        "agreementKey": FlutterStandardTypedData(bytes: key.rawRepresentation),
        "keyChanged": keyChanged,
      ])
    } catch {
      result(FlutterError(
        code: "agreement-key-failed",
        message: "The agreement key could not be loaded or created.",
        details: String(describing: error)
      ))
    }
  }

  private func loadPublicKey(result: @escaping FlutterResult) {
    do {
      guard let key = try loadPrivateKey() else {
        result(FlutterError(
          code: "key-not-found",
          message: "No Secure Enclave signing identity exists.",
          details: nil
        ))
        return
      }
      result(FlutterStandardTypedData(bytes: key.publicKey.x963Representation))
    } catch {
      result(FlutterError(
        code: "key-load-failed",
        message: "The Secure Enclave signing key could not be loaded.",
        details: String(describing: error)
      ))
    }
  }

  private func signDigest(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let bytes = arguments as? FlutterStandardTypedData else {
      result(FlutterError(
        code: "invalid-digest",
        message: "The digest must be a 32-byte byte array.",
        details: nil
      ))
      return
    }

    let digest = bytes.data
    guard digest.count == 32 else {
      result(FlutterError(
        code: "invalid-digest",
        message: "The digest must be exactly 32 bytes.",
        details: nil
      ))
      return
    }

    do {
      guard let key = try loadPrivateKey() else {
        result(FlutterError(
          code: "key-not-found",
          message: "No Secure Enclave signing identity exists.",
          details: nil
        ))
        return
      }

      let rawDigest = try RawSHA256Digest(data: digest)
      let signature = try key.signature(for: rawDigest)
      let raw = signature.rawRepresentation
      guard raw.count == 64 else {
        throw SigningPluginError.invalidSignatureLength(raw.count)
      }
      result(FlutterStandardTypedData(bytes: raw))
    } catch {
      result(FlutterError(
        code: "signing-failed",
        message: "The digest could not be signed.",
        details: String(describing: error)
      ))
    }
  }

  private func deleteIdentity(result: @escaping FlutterResult) {
    let signingStatus = deleteStoredValue(account: Self.signingKeychainAccount)
    let agreementStatus = deleteStoredValue(account: Self.agreementKeychainAccount)
    let baselineStatus = deleteStoredValue(account: Self.identityBaselineKeychainAccount)
    if isDeleted(signingStatus) && isDeleted(agreementStatus)
        && isDeleted(baselineStatus) {
      result(true)
      return
    }
    result(FlutterError(
      code: "key-delete-failed",
      message: "The identity keys could not be deleted.",
      details: [
        "signingStatus": signingStatus,
        "agreementStatus": agreementStatus,
      ]
    ))
  }

  private func deleteStoredValue(account: String) -> OSStatus {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.keychainService,
      kSecAttrAccount as String: account,
    ]
    return SecItemDelete(query as CFDictionary)
  }

  private func isDeleted(_ status: OSStatus) -> Bool {
    status == errSecSuccess || status == errSecItemNotFound
  }

  private func loadPrivateKey() throws -> SecureEnclave.P256.Signing.PrivateKey? {
    guard let stored = try loadValue(account: Self.signingKeychainAccount) else {
      return nil
    }
    return try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: stored)
  }

  private func loadValue(account: String) throws -> Data? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.keychainService,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess, let data = item as? Data else {
      throw SigningPluginError.keychainStatus(status)
    }
    return data
  }

  private func storeValue(_ data: Data, account: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.keychainService,
      kSecAttrAccount as String: account,
    ]
    let deleteStatus = SecItemDelete(query as CFDictionary)
    guard isDeleted(deleteStatus) else {
      throw SigningPluginError.keychainStatus(deleteStatus)
    }

    let attributes: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.keychainService,
      kSecAttrAccount as String: account,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    ]

    let status = SecItemAdd(attributes as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw SigningPluginError.keychainStatus(status)
    }
  }
}

private enum SigningPluginError: Error {
  case keychainStatus(OSStatus)
  case keyNotFound
  case invalidSignatureLength(Int)
  case invalidDigestLength(Int)
  case accessControlCreation(CFError?)
}

private struct RawSHA256Digest: Digest {
  static let byteCount = 32

  let bytes: [UInt8]

  init(data: Data) throws {
    let array = Array(data)
    guard array.count == Self.byteCount else {
      throw SigningPluginError.invalidDigestLength(array.count)
    }
    bytes = array
  }

  var description: String {
    bytes.map { String(format: "%02x", $0) }.joined()
  }

  func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
    try bytes.withUnsafeBytes(body)
  }
}
