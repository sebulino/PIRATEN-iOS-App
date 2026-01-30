//
//  KeychainCredentialStoreTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 30.01.26.
//

import Foundation
import Testing
@testable import PIRATEN

/// Tests for KeychainCredentialStore functionality.
/// Uses a dedicated test service identifier to avoid conflicts with real app data.
struct CredentialStoreTests {

    /// A unique service identifier for test isolation
    private let testService = "de.meine-piraten.PIRATEN.tests.\(UUID().uuidString)"

    /// Test key used across tests - using a generic name to avoid any PII
    private let testKey = "test_key"

    // MARK: - Set/Get Tests

    @Test func setAndGetValue() async throws {
        let keychain = KeychainCredentialStore(service: testService)
        let testValue = "test_value_123"

        // Set value
        try keychain.set(testValue, forKey: testKey)

        // Get value
        let retrieved = try keychain.get(forKey: testKey)
        #expect(retrieved == testValue)

        // Cleanup
        try keychain.delete(forKey: testKey)
    }

    @Test func getReturnsNilForNonexistentKey() async throws {
        let keychain = KeychainCredentialStore(service: testService)

        let result = try keychain.get(forKey: "nonexistent_key_\(UUID().uuidString)")
        #expect(result == nil)
    }

    @Test func setOverwritesExistingValue() async throws {
        let keychain = KeychainCredentialStore(service: testService)
        let originalValue = "original_value"
        let updatedValue = "updated_value"

        // Set original value
        try keychain.set(originalValue, forKey: testKey)

        // Overwrite with new value
        try keychain.set(updatedValue, forKey: testKey)

        // Verify new value
        let retrieved = try keychain.get(forKey: testKey)
        #expect(retrieved == updatedValue)

        // Cleanup
        try keychain.delete(forKey: testKey)
    }

    // MARK: - Delete Tests

    @Test func deleteRemovesValue() async throws {
        let keychain = KeychainCredentialStore(service: testService)
        let testValue = "value_to_delete"

        // Set value
        try keychain.set(testValue, forKey: testKey)

        // Verify it exists
        let beforeDelete = try keychain.get(forKey: testKey)
        #expect(beforeDelete == testValue)

        // Delete
        try keychain.delete(forKey: testKey)

        // Verify it's gone
        let afterDelete = try keychain.get(forKey: testKey)
        #expect(afterDelete == nil)
    }

    @Test func deleteNonexistentKeyDoesNotThrow() async throws {
        let keychain = KeychainCredentialStore(service: testService)

        // This should not throw
        try keychain.delete(forKey: "nonexistent_key_\(UUID().uuidString)")
    }

    // MARK: - Contains Tests

    @Test func containsReturnsTrueForExistingKey() async throws {
        let keychain = KeychainCredentialStore(service: testService)

        try keychain.set("some_value", forKey: testKey)

        #expect(keychain.contains(key: testKey) == true)

        // Cleanup
        try keychain.delete(forKey: testKey)
    }

    @Test func containsReturnsFalseForNonexistentKey() async throws {
        let keychain = KeychainCredentialStore(service: testService)

        #expect(keychain.contains(key: "nonexistent_key_\(UUID().uuidString)") == false)
    }

    // MARK: - Special Character Tests

    @Test func handlesSpecialCharactersInValue() async throws {
        let keychain = KeychainCredentialStore(service: testService)
        let specialValue = "special!@#$%^&*()_+-=[]{}|;':\",./<>?äöü中文"

        try keychain.set(specialValue, forKey: testKey)

        let retrieved = try keychain.get(forKey: testKey)
        #expect(retrieved == specialValue)

        // Cleanup
        try keychain.delete(forKey: testKey)
    }
}
