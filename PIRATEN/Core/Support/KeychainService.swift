//
//  KeychainService.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation
import Security

/// Errors that can occur during Keychain operations
enum KeychainError: Error, Equatable {
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
    case encodingFailed
    case decodingFailed
}

/// Protocol for secure credential storage operations.
/// This abstraction allows swapping implementations for testing or alternative storage backends.
protocol CredentialStore {
    func set(_ value: String, forKey key: String) throws
    func get(forKey key: String) throws -> String?
    func delete(forKey key: String) throws
    func contains(key: String) -> Bool
}

/// A wrapper around iOS Keychain Services for secure storage of sensitive data.
/// This service is designed to store authentication tokens and similar secrets.
///
/// Note: This implementation does NOT log any values, tokens, or PII.
final class KeychainCredentialStore: CredentialStore {

    /// The service identifier used to namespace Keychain items
    private let service: String

    /// Creates a new KeychainService instance
    /// - Parameter service: The service identifier for namespacing Keychain items.
    ///                      Defaults to the app's bundle identifier.
    init(service: String = Bundle.main.bundleIdentifier ?? "de.meine-piraten.PIRATEN") {
        self.service = service
    }

    /// Stores a string value securely in the Keychain
    /// - Parameters:
    ///   - value: The string value to store
    ///   - key: The key to associate with the value
    /// - Throws: `KeychainError` if the operation fails
    func set(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // First, try to delete any existing item
        try? delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            }
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Retrieves a string value from the Keychain
    /// - Parameter key: The key associated with the value
    /// - Returns: The stored string value, or nil if not found
    /// - Throws: `KeychainError` if the operation fails (other than item not found)
    func get(forKey key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.decodingFailed
        }

        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }

        return string
    }

    /// Deletes a value from the Keychain
    /// - Parameter key: The key associated with the value to delete
    /// - Throws: `KeychainError` if the operation fails (item not found is NOT an error)
    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Item not found is acceptable - it means nothing to delete
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Checks if a key exists in the Keychain
    /// - Parameter key: The key to check
    /// - Returns: true if the key exists, false otherwise
    func contains(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

/// In-memory implementation of CredentialStore for testing and SwiftUI previews.
/// Note: This does NOT persist data and should NOT be used in production.
final class InMemoryCredentialStore: CredentialStore {
    private var storage: [String: String] = [:]

    func set(_ value: String, forKey key: String) throws {
        storage[key] = value
    }

    func get(forKey key: String) throws -> String? {
        return storage[key]
    }

    func delete(forKey key: String) throws {
        storage.removeValue(forKey: key)
    }

    func contains(key: String) -> Bool {
        return storage[key] != nil
    }
}
