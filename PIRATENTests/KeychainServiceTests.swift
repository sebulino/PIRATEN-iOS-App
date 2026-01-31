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

// MARK: - Token Bundle Storage Tests

/// Tests for token bundle storage and retrieval functionality.
/// Verifies that OAuth tokens can be stored and restored correctly.
struct TokenBundleStorageTests {

    /// A unique service identifier for test isolation
    private let testService = "de.meine-piraten.PIRATEN.token.tests.\(UUID().uuidString)"

    /// Storage keys matching OIDCAuthRepository
    private let accessTokenKey = "oidc_access_token"
    private let refreshTokenKey = "oidc_refresh_token"
    private let idTokenKey = "oidc_id_token"
    private let tokenExpirationKey = "oidc_token_expiration"

    // MARK: - Token Bundle Storage

    @Test func storeAndRetrieveFullTokenBundle() async throws {
        let keychain = KeychainCredentialStore(service: testService)
        let accessToken = "test_access_token_abc123"
        let refreshToken = "test_refresh_token_xyz789"
        let idToken = "test_id_token_jwt.payload.signature"
        let expirationDate = Date().addingTimeInterval(3600) // 1 hour from now
        let expirationString = String(expirationDate.timeIntervalSince1970)

        // Store all token bundle values
        try keychain.set(accessToken, forKey: accessTokenKey)
        try keychain.set(refreshToken, forKey: refreshTokenKey)
        try keychain.set(idToken, forKey: idTokenKey)
        try keychain.set(expirationString, forKey: tokenExpirationKey)

        // Retrieve and verify
        let retrievedAccess = try keychain.get(forKey: accessTokenKey)
        let retrievedRefresh = try keychain.get(forKey: refreshTokenKey)
        let retrievedId = try keychain.get(forKey: idTokenKey)
        let retrievedExpiration = try keychain.get(forKey: tokenExpirationKey)

        #expect(retrievedAccess == accessToken)
        #expect(retrievedRefresh == refreshToken)
        #expect(retrievedId == idToken)
        #expect(retrievedExpiration == expirationString)

        // Verify expiration can be parsed back to date
        if let expString = retrievedExpiration,
           let timestamp = Double(expString) {
            let restoredDate = Date(timeIntervalSince1970: timestamp)
            // Allow 1 second tolerance for floating point
            #expect(abs(restoredDate.timeIntervalSince(expirationDate)) < 1)
        } else {
            Issue.record("Failed to parse expiration timestamp")
        }

        // Cleanup
        try keychain.delete(forKey: accessTokenKey)
        try keychain.delete(forKey: refreshTokenKey)
        try keychain.delete(forKey: idTokenKey)
        try keychain.delete(forKey: tokenExpirationKey)
    }

    @Test func storeMinimalTokenBundle() async throws {
        let keychain = KeychainCredentialStore(service: testService)
        let accessToken = "minimal_access_token"

        // Store only access token (minimal valid bundle)
        try keychain.set(accessToken, forKey: accessTokenKey)

        // Verify access token is stored
        #expect(keychain.contains(key: accessTokenKey) == true)

        // Verify optional tokens are not present
        #expect(keychain.contains(key: refreshTokenKey) == false)
        #expect(keychain.contains(key: idTokenKey) == false)
        #expect(keychain.contains(key: tokenExpirationKey) == false)

        // Cleanup
        try keychain.delete(forKey: accessTokenKey)
    }

    @Test func sessionValidityWithValidToken() async throws {
        let keychain = KeychainCredentialStore(service: testService)
        let accessToken = "valid_access_token"
        // Token expires in 2 hours (well beyond 60 second threshold)
        let expirationDate = Date().addingTimeInterval(7200)
        let expirationString = String(expirationDate.timeIntervalSince1970)

        try keychain.set(accessToken, forKey: accessTokenKey)
        try keychain.set(expirationString, forKey: tokenExpirationKey)

        // Verify token is present
        #expect(keychain.contains(key: accessTokenKey) == true)

        // Verify expiration check logic (simulating hasValidSession)
        if let expString = try keychain.get(forKey: tokenExpirationKey),
           let timestamp = Double(expString) {
            let expDate = Date(timeIntervalSince1970: timestamp)
            // Token should be valid (more than 60 seconds until expiry)
            #expect(expDate.timeIntervalSinceNow > 60)
        } else {
            Issue.record("Could not verify token expiration")
        }

        // Cleanup
        try keychain.delete(forKey: accessTokenKey)
        try keychain.delete(forKey: tokenExpirationKey)
    }

    @Test func sessionValidityWithExpiredToken() async throws {
        let keychain = KeychainCredentialStore(service: testService)
        let accessToken = "expired_access_token"
        // Token expired 1 hour ago
        let expirationDate = Date().addingTimeInterval(-3600)
        let expirationString = String(expirationDate.timeIntervalSince1970)

        try keychain.set(accessToken, forKey: accessTokenKey)
        try keychain.set(expirationString, forKey: tokenExpirationKey)

        // Verify expiration check logic (simulating hasValidSession)
        if let expString = try keychain.get(forKey: tokenExpirationKey),
           let timestamp = Double(expString) {
            let expDate = Date(timeIntervalSince1970: timestamp)
            // Token should be invalid (expired)
            #expect(expDate.timeIntervalSinceNow < 60)
        } else {
            Issue.record("Could not verify token expiration")
        }

        // Cleanup
        try keychain.delete(forKey: accessTokenKey)
        try keychain.delete(forKey: tokenExpirationKey)
    }

    @Test func sessionValidityWithRefreshTokenFallback() async throws {
        let keychain = KeychainCredentialStore(service: testService)
        let accessToken = "expiring_access_token"
        let refreshToken = "valid_refresh_token"
        // Token expires in 30 seconds (within 60 second threshold)
        let expirationDate = Date().addingTimeInterval(30)
        let expirationString = String(expirationDate.timeIntervalSince1970)

        try keychain.set(accessToken, forKey: accessTokenKey)
        try keychain.set(refreshToken, forKey: refreshTokenKey)
        try keychain.set(expirationString, forKey: tokenExpirationKey)

        // Token is about to expire
        if let expString = try keychain.get(forKey: tokenExpirationKey),
           let timestamp = Double(expString) {
            let expDate = Date(timeIntervalSince1970: timestamp)
            let isAboutToExpire = expDate.timeIntervalSinceNow < 60

            #expect(isAboutToExpire == true)
            // But we have a refresh token for recovery
            #expect(keychain.contains(key: refreshTokenKey) == true)
        }

        // Cleanup
        try keychain.delete(forKey: accessTokenKey)
        try keychain.delete(forKey: refreshTokenKey)
        try keychain.delete(forKey: tokenExpirationKey)
    }

    @Test func clearAllTokens() async throws {
        let keychain = KeychainCredentialStore(service: testService)

        // Store all token values
        try keychain.set("access", forKey: accessTokenKey)
        try keychain.set("refresh", forKey: refreshTokenKey)
        try keychain.set("id", forKey: idTokenKey)
        try keychain.set("123456", forKey: tokenExpirationKey)

        // Verify all are stored
        #expect(keychain.contains(key: accessTokenKey) == true)
        #expect(keychain.contains(key: refreshTokenKey) == true)
        #expect(keychain.contains(key: idTokenKey) == true)
        #expect(keychain.contains(key: tokenExpirationKey) == true)

        // Clear all (simulating logout)
        try keychain.delete(forKey: accessTokenKey)
        try keychain.delete(forKey: refreshTokenKey)
        try keychain.delete(forKey: idTokenKey)
        try keychain.delete(forKey: tokenExpirationKey)

        // Verify all are cleared
        #expect(keychain.contains(key: accessTokenKey) == false)
        #expect(keychain.contains(key: refreshTokenKey) == false)
        #expect(keychain.contains(key: idTokenKey) == false)
        #expect(keychain.contains(key: tokenExpirationKey) == false)
    }

    @Test func tokenOverwritePreservesOtherTokens() async throws {
        let keychain = KeychainCredentialStore(service: testService)

        // Store initial bundle
        try keychain.set("original_access", forKey: accessTokenKey)
        try keychain.set("original_refresh", forKey: refreshTokenKey)

        // Overwrite only access token
        try keychain.set("new_access", forKey: accessTokenKey)

        // Verify access is updated but refresh is preserved
        let access = try keychain.get(forKey: accessTokenKey)
        let refresh = try keychain.get(forKey: refreshTokenKey)

        #expect(access == "new_access")
        #expect(refresh == "original_refresh")

        // Cleanup
        try keychain.delete(forKey: accessTokenKey)
        try keychain.delete(forKey: refreshTokenKey)
    }
}
