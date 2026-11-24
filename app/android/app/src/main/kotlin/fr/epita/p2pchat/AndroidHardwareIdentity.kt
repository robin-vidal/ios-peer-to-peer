package fr.epita.p2pchat

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.math.BigInteger
import java.security.KeyFactory
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.security.spec.ECPublicKeySpec
import java.security.spec.PKCS8EncodedKeySpec
import java.security.spec.X509EncodedKeySpec
import java.security.interfaces.ECPrivateKey
import java.security.interfaces.ECPublicKey

internal class AndroidHardwareIdentity(
    context: Context,
) : MethodChannel.MethodCallHandler {
    private val preferences = context.getSharedPreferences(
        "p2pchat_hardware_identity",
        Context.MODE_PRIVATE,
    )

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "isAvailable") {
            result.success(isHardwareSigningAvailable())
            return
        }

        try {
            when (call.method) {
                "createOrLoad" -> result.success(createOrLoadSigningKey())
                "getPublicKey" -> result.success(loadSigningKey().second)
                "createOrLoadAgreementKey" -> result.success(createOrLoadAgreementKey())
                "signDigest" -> {
                    val digest = call.arguments as? ByteArray
                    if (digest == null || digest.size != 32) {
                        throw IdentityException(
                            "invalid-digest",
                            "The digest must be exactly 32 bytes.",
                        )
                    }
                    result.success(signDigest(digest))
                }
                "deleteIdentity" -> {
                    deleteIdentity()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (error: IdentityException) {
            result.error(error.code, error.message, null)
        } catch (error: Exception) {
            result.error(
                "identity-operation-failed",
                error.message ?: "The hardware-backed identity operation failed.",
                null,
            )
        }
    }

    private fun isHardwareSigningAvailable(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return false
        }
        val alias = "p2pchat-hardware-probe"
        return try {
            keyStore().deleteEntry(alias)
            val pair = generateSigningKey(alias)
            if (!isInsideSecureHardware(pair.private)) {
                return false
            }
            val signer = Signature.getInstance("NONEwithECDSA")
            signer.initSign(pair.private)
            signer.update(ByteArray(32))
            derToRaw(signer.sign()).size == PRIVATE_KEY_SIZE * 2
        } catch (_: Exception) {
            false
        } finally {
            try {
                keyStore().deleteEntry(alias)
            } catch (_: Exception) {
                Unit
            }
        }
    }

    private fun createOrLoadSigningKey(): Map<String, Any> {
        val baseline = readBaseline()
        var keyChanged = false
        val pair = try {
            if (keyStore().containsAlias(SIGNING_ALIAS)) {
                try {
                    loadSigningKey().first
                } catch (_: Exception) {
                    keyStore().deleteEntry(SIGNING_ALIAS)
                    keyChanged = baseline != null
                    generateSigningKey(SIGNING_ALIAS)
                }
            } else {
                keyChanged = baseline != null
                generateSigningKey(SIGNING_ALIAS)
            }
        } catch (error: IdentityException) {
            throw error
        } catch (error: Exception) {
            throw IdentityException(
                "key-creation-failed",
                error.message ?: "Hardware-backed P-256 signing key creation failed.",
            )
        }

        if (!isInsideSecureHardware(pair.private)) {
            keyStore().deleteEntry(SIGNING_ALIAS)
            throw IdentityException(
                "secure-hardware-unavailable",
                "Android Keystore did not create a hardware-backed signing key.",
            )
        }

        val publicKey = x963(pair.public)
        if (baseline != null) {
            if (baseline.size != IDENTITY_SIZE ||
                !baseline.copyOfRange(0, PUBLIC_KEY_SIZE).contentEquals(publicKey)
            ) {
                keyChanged = true
            }
        }
        return mapOf("publicKey" to publicKey, "keyChanged" to keyChanged)
    }

    private fun createOrLoadAgreementKey(): Map<String, Any> {
        val previousBaseline = readBaseline()
        val agreement = try {
            loadAgreementKey()
        } catch (_: Exception) {
            null
        }
        var keyChanged = false
        val (privateKey, publicKey) = if (agreement != null) {
            agreement
        } else {
            keyChanged = previousBaseline != null
            createAgreementKey().also { saveAgreementKey(it.first, it.second) }
        }

        val signingPublicKey = try {
            x963(loadSigningKey().first.public)
        } catch (error: Exception) {
            throw IdentityException(
                "key-load-failed",
                error.message ?: "The Android Keystore signing key could not be loaded.",
            )
        }
        if (previousBaseline != null) {
            if (previousBaseline.size != IDENTITY_SIZE ||
                !previousBaseline.copyOfRange(0, PUBLIC_KEY_SIZE)
                    .contentEquals(signingPublicKey) ||
                !previousBaseline.copyOfRange(PUBLIC_KEY_SIZE, IDENTITY_SIZE)
                    .contentEquals(publicKey)
            ) {
                keyChanged = true
            }
        }
        saveBaseline(signingPublicKey + publicKey)
        return mapOf(
            "agreementKey" to fixedBytes(privateKey.s, PRIVATE_KEY_SIZE),
            "keyChanged" to keyChanged,
        )
    }

    private fun signDigest(digest: ByteArray): ByteArray {
        val privateKey = try {
            loadSigningKey().first.private
        } catch (error: Exception) {
            throw IdentityException(
                "key-load-failed",
                error.message ?: "The Android Keystore signing key could not be loaded.",
            )
        }
        if (!isInsideSecureHardware(privateKey)) {
            throw IdentityException(
                "secure-hardware-unavailable",
                "The Android Keystore signing key is not hardware-backed.",
            )
        }

        val signer = Signature.getInstance("NONEwithECDSA")
        signer.initSign(privateKey)
        signer.update(digest)
        return derToRaw(signer.sign())
    }

    private fun generateSigningKey(alias: String): KeyPair {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            throw IdentityException(
                "secure-hardware-unavailable",
                "Hardware-backed P-256 signing requires Android 6.0 or later.",
            )
        }
        val generator = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            ANDROID_KEY_STORE,
        )
        generator.initialize(
            KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
            )
                .setAlgorithmParameterSpec(ECGenParameterSpec(CURVE))
                .setDigests(KeyProperties.DIGEST_NONE)
                .setUserAuthenticationRequired(false)
                .build(),
        )
        return generator.generateKeyPair()
    }

    private fun loadSigningKey(): Pair<KeyPair, ByteArray> {
        val store = keyStore()
        val certificate = store.getCertificate(SIGNING_ALIAS)
            ?: throw IdentityException("key-not-found", "No signing identity exists.")
        val privateKey = store.getKey(SIGNING_ALIAS, null)
            ?: throw IdentityException("key-not-found", "No signing identity exists.")
        val pair = KeyPair(certificate.publicKey, privateKey as java.security.PrivateKey)
        if (!isInsideSecureHardware(pair.private)) {
            throw IdentityException(
                "secure-hardware-unavailable",
                "The Android Keystore signing key is not hardware-backed.",
            )
        }
        return pair to x963(pair.public)
    }

    @Suppress("DEPRECATION")
    private fun isInsideSecureHardware(privateKey: java.security.PrivateKey): Boolean {
        val keyInfo = KeyFactory.getInstance(privateKey.algorithm, ANDROID_KEY_STORE)
            .getKeySpec(privateKey, KeyInfo::class.java)
        return keyInfo.isInsideSecureHardware
    }

    private fun createAgreementKey(): Pair<ECPrivateKey, ByteArray> {
        val generator = KeyPairGenerator.getInstance("EC")
        generator.initialize(ECGenParameterSpec(CURVE))
        val pair = generator.generateKeyPair()
        val privateKey = pair.private as ECPrivateKey
        return privateKey to x963(pair.public)
    }

    private fun loadAgreementKey(): Pair<ECPrivateKey, ByteArray>? {
        val privateEncoded = preferences.getString(AGREEMENT_PRIVATE, null) ?: return null
        val publicEncoded = preferences.getString(AGREEMENT_PUBLIC, null) ?: return null
        val factory = KeyFactory.getInstance("EC")
        val privateKey = factory.generatePrivate(
            PKCS8EncodedKeySpec(Base64.decode(privateEncoded, Base64.NO_WRAP)),
        ) as ECPrivateKey
        val publicKey = factory.generatePublic(
            X509EncodedKeySpec(Base64.decode(publicEncoded, Base64.NO_WRAP)),
        ) as ECPublicKey
        if (privateKey.params.curve.field.fieldSize != 256 ||
            publicKey.params.curve.field.fieldSize != 256 ||
            !matches(privateKey, publicKey)
        ) {
            throw IllegalArgumentException("The stored agreement key is invalid.")
        }
        return privateKey to x963(publicKey)
    }

    private fun matches(privateKey: ECPrivateKey, publicKey: ECPublicKey): Boolean {
        val challenge = ByteArray(32) { it.toByte() }
        val signer = Signature.getInstance("SHA256withECDSA")
        signer.initSign(privateKey)
        signer.update(challenge)
        val signature = signer.sign()
        val verifier = Signature.getInstance("SHA256withECDSA")
        verifier.initVerify(publicKey)
        verifier.update(challenge)
        return verifier.verify(signature)
    }

    private fun saveAgreementKey(privateKey: ECPrivateKey, publicKey: ByteArray) {
        val encodedPrivate = privateKey.encoded
        val encodedPublic = KeyFactory.getInstance("EC")
            .generatePublic(
                ECPublicKeySpec(
                    java.security.spec.ECPoint(
                        BigInteger(1, publicKey.copyOfRange(1, 33)),
                        BigInteger(1, publicKey.copyOfRange(33, 65)),
                    ),
                    privateKey.params,
                ),
            ).encoded
        if (!preferences.edit()
                .putString(AGREEMENT_PRIVATE, Base64.encodeToString(encodedPrivate, Base64.NO_WRAP))
                .putString(AGREEMENT_PUBLIC, Base64.encodeToString(encodedPublic, Base64.NO_WRAP))
                .commit()
        ) {
            throw IdentityException(
                "agreement-key-failed",
                "The agreement key could not be persisted.",
            )
        }
    }

    private fun readBaseline(): ByteArray? {
        val encoded = preferences.getString(IDENTITY_BASELINE, null) ?: return null
        return try {
            Base64.decode(encoded, Base64.NO_WRAP)
        } catch (_: IllegalArgumentException) {
            byteArrayOf()
        }
    }

    private fun saveBaseline(value: ByteArray) {
        if (!preferences.edit()
                .putString(IDENTITY_BASELINE, Base64.encodeToString(value, Base64.NO_WRAP))
                .commit()
        ) {
            throw IdentityException(
                "identity-state-failed",
                "The identity baseline could not be persisted.",
            )
        }
    }

    private fun deleteIdentity() {
        keyStore().deleteEntry(SIGNING_ALIAS)
        if (!preferences.edit()
                .remove(AGREEMENT_PRIVATE)
                .remove(AGREEMENT_PUBLIC)
                .remove(IDENTITY_BASELINE)
                .commit()
        ) {
            throw IdentityException(
                "key-delete-failed",
                "The identity state could not be deleted.",
            )
        }
    }

    private fun keyStore(): KeyStore =
        KeyStore.getInstance(ANDROID_KEY_STORE).apply { load(null) }

    private fun x963(publicKey: java.security.PublicKey): ByteArray {
        val point = (publicKey as ECPublicKey).w
        return byteArrayOf(0x04) +
            fixedBytes(point.affineX, PUBLIC_KEY_SIZE / 2) +
            fixedBytes(point.affineY, PUBLIC_KEY_SIZE / 2)
    }

    private fun derToRaw(signature: ByteArray): ByteArray {
        var offset = 0
        require((signature[offset++].toInt() and 0xff) == 0x30) { "Invalid ECDSA signature." }
        offset = skipDerLength(signature, offset)
        val r = readDerInteger(signature, offset).also { offset = it.second }.first
        val s = readDerInteger(signature, offset).first
        return fixedBytes(BigInteger(1, r), PRIVATE_KEY_SIZE) +
            fixedBytes(BigInteger(1, s), PRIVATE_KEY_SIZE)
    }

    private fun readDerInteger(signature: ByteArray, start: Int): Pair<ByteArray, Int> {
        var offset = start
        require((signature[offset++].toInt() and 0xff) == 0x02) { "Invalid ECDSA integer." }
        val length = signature[offset++].toInt() and 0xff
        require(length > 0 && offset + length <= signature.size) { "Invalid ECDSA integer length." }
        var value = signature.copyOfRange(offset, offset + length)
        while (value.size > 1 && value[0] == 0.toByte()) {
            value = value.copyOfRange(1, value.size)
        }
        require(value.size <= PRIVATE_KEY_SIZE) { "ECDSA integer exceeds P-256 width." }
        return value to (offset + length)
    }

    private fun skipDerLength(signature: ByteArray, start: Int): Int {
        val first = signature[start].toInt() and 0xff
        if (first < 0x80) return start + 1
        val byteCount = first and 0x7f
        require(byteCount in 1..2 && start + 1 + byteCount <= signature.size) {
            "Invalid ECDSA signature length."
        }
        return start + 1 + byteCount
    }

    private fun fixedBytes(value: BigInteger, size: Int): ByteArray {
        val bytes = value.toByteArray().let {
            if (it.size > size && it[0] == 0.toByte()) it.copyOfRange(1, it.size) else it
        }
        require(bytes.size <= size) { "Integer exceeds expected key width." }
        return ByteArray(size - bytes.size) + bytes
    }

    private class IdentityException(
        val code: String,
        override val message: String,
    ) : Exception(message)

    private companion object {
        const val ANDROID_KEY_STORE = "AndroidKeyStore"
        const val SIGNING_ALIAS = "p2pchat-p256-signing"
        const val CURVE = "secp256r1"
        const val PRIVATE_KEY_SIZE = 32
        const val PUBLIC_KEY_SIZE = 65
        const val IDENTITY_SIZE = PUBLIC_KEY_SIZE * 2
        const val AGREEMENT_PRIVATE = "agreement_private"
        const val AGREEMENT_PUBLIC = "agreement_public"
        const val IDENTITY_BASELINE = "identity_baseline"
    }
}
