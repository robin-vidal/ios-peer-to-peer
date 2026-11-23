import CryptoKit
import Flutter
import Foundation
import Security

final class SecureEnclaveSigningPlugin: NSObject, FlutterPlugin {
  private static let channelName = "fr.epita.p2pchat/secure_enclave_signing"
  private static let keychainAccount = "long-term-p256-signing-key"
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
      if let stored = try loadWrappedKey() {
        do {
          key = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: stored)
        } catch {
          result(FlutterError(
            code: "key-load-failed",
            message: "The stored Secure Enclave signing key could not be loaded.",
            details: String(describing: error)
          ))
          return
        }
      } else {
        do {
          key = try SecureEnclave.P256.Signing.PrivateKey()
          try storeWrappedKey(key.dataRepresentation)
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
      ])
    } catch {
      result(FlutterError(
        code: "key-load-failed",
        message: "The stored signing key could not be accessed.",
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
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.keychainService,
      kSecAttrAccount as String: Self.keychainAccount,
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      result(FlutterError(
        code: "key-delete-failed",
        message: "The Secure Enclave signing key could not be deleted.",
        details: status
      ))
      return
    }
    result(true)
  }

  private func loadPrivateKey() throws -> SecureEnclave.P256.Signing.PrivateKey? {
    guard let stored = try loadWrappedKey() else {
      return nil
    }
    return try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: stored)
  }

  private func loadWrappedKey() throws -> Data? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.keychainService,
      kSecAttrAccount as String: Self.keychainAccount,
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

  private func storeWrappedKey(_ data: Data) throws {
    let attributes: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.keychainService,
      kSecAttrAccount as String: Self.keychainAccount,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    ]

    SecItemDelete([
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.keychainService,
      kSecAttrAccount as String: Self.keychainAccount,
    ] as CFDictionary)

    let status = SecItemAdd(attributes as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw SigningPluginError.keychainStatus(status)
    }
  }
}

private enum SigningPluginError: Error {
  case keychainStatus(OSStatus)
  case invalidSignatureLength(Int)
  case invalidDigestLength(Int)
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
