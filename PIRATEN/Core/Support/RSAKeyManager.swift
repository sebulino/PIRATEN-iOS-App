//
//  RSAKeyManager.swift
//  PIRATEN
//
//  Created by Claude Code on 01.02.26.
//

import Foundation
import Security

/// Errors that can occur during RSA key operations
enum RSAKeyError: Error, Equatable {
    case keyGenerationFailed(OSStatus)
    case keyNotFound
    case exportFailed
    case invalidKeyData
    case keychainStorageFailed(OSStatus)
}

/// Manages RSA key pair generation and storage for Discourse User API Key authentication.
/// The public key is exported in PEM format for sending to Discourse.
/// The private key is stored securely in the Keychain for decrypting the auth response.
///
/// ## Key Lifecycle
/// - Keys are generated once and reused for subsequent auth attempts
/// - Private key is stored in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
/// - Public key is ephemeral and derived from the stored private key when needed
///
/// ## Security
/// - 2048-bit RSA key size (industry standard, balances security and performance)
/// - Private key never leaves the Keychain
/// - No logging of key material
final class RSAKeyManager {

    // MARK: - Constants

    /// Key size in bits (2048 is the recommended minimum for RSA)
    private static let keySize = 2048

    /// Keychain tag for the Discourse auth RSA private key
    private static let privateKeyTag = "de.meine-piraten.PIRATEN.discourse-rsa-private"

    // MARK: - Public Interface

    /// Generates a new RSA key pair and stores the private key in Keychain.
    /// If a key pair already exists, this will replace it.
    /// - Returns: The private key reference for internal use
    /// - Throws: RSAKeyError if generation or storage fails
    func generateKeyPair() throws -> SecKey {
        // Define key generation parameters
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: Self.keySize,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: Self.privateKeyTag.data(using: .utf8)!,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
        ]

        // Generate key pair
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            if let err = error?.takeRetainedValue() {
                let osStatus = CFErrorGetCode(err)
                throw RSAKeyError.keyGenerationFailed(OSStatus(osStatus))
            }
            throw RSAKeyError.keyGenerationFailed(errSecInternalError)
        }

        return privateKey
    }

    /// Retrieves the stored private key from Keychain.
    /// - Returns: The private key reference, or nil if not found
    /// - Throws: RSAKeyError if Keychain access fails
    func getPrivateKey() throws -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Self.privateKeyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw RSAKeyError.keychainStorageFailed(status)
        }

        return (item as! SecKey)
    }

    /// Exports the public key in PEM format for sending to Discourse.
    /// - Parameter privateKey: The private key reference (from which public key is derived)
    /// - Returns: PEM-encoded public key string
    /// - Throws: RSAKeyError if export fails
    func exportPublicKeyAsPEM(from privateKey: SecKey) throws -> String {
        // Get the public key from the private key
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw RSAKeyError.exportFailed
        }

        // Export public key as DER data
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw RSAKeyError.exportFailed
        }

        // Convert to PEM format
        // PEM format: -----BEGIN PUBLIC KEY-----\n<base64>\n-----END PUBLIC KEY-----
        let base64 = keyData.base64EncodedString(options: .lineLength64Characters)
        let pem = """
        -----BEGIN PUBLIC KEY-----
        \(base64)
        -----END PUBLIC KEY-----
        """

        return pem
    }

    /// Ensures a key pair exists, generating one if necessary.
    /// - Returns: The private key reference
    /// - Throws: RSAKeyError if key retrieval or generation fails
    func ensureKeyPairExists() throws -> SecKey {
        if let existingKey = try getPrivateKey() {
            return existingKey
        }
        return try generateKeyPair()
    }

    /// Deletes the stored private key from Keychain.
    /// Used during logout or key rotation.
    /// - Throws: RSAKeyError if deletion fails (item not found is NOT an error)
    func deleteKeyPair() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: Self.privateKeyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Item not found is acceptable - nothing to delete
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RSAKeyError.keychainStorageFailed(status)
        }
    }

    /// Decrypts data using the stored RSA private key.
    /// Used to decrypt the Discourse User API Key response.
    /// - Parameters:
    ///   - encryptedData: The encrypted data from Discourse
    ///   - privateKey: The private key to use for decryption
    /// - Returns: Decrypted data
    /// - Throws: RSAKeyError if decryption fails
    func decrypt(_ encryptedData: Data, using privateKey: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let decryptedData = SecKeyCreateDecryptedData(
            privateKey,
            .rsaEncryptionPKCS1,
            encryptedData as CFData,
            &error
        ) as Data? else {
            throw RSAKeyError.exportFailed
        }

        return decryptedData
    }
}
