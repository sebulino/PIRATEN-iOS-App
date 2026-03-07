//
//  KeychainDiscourseAPIKeyProvider.swift
//  PIRATEN
//
//  Created by Claude Code on 02.02.26.
//

import Foundation

/// Keychain-backed implementation of DiscourseAPIKeyProvider.
/// Retrieves stored Discourse credentials from the iOS Keychain via CredentialStore.
final class KeychainDiscourseAPIKeyProvider: DiscourseAPIKeyProvider, @unchecked Sendable {

    // MARK: - Dependencies

    private let credentialStore: CredentialStore

    // MARK: - Initialization

    /// Creates a new KeychainDiscourseAPIKeyProvider.
    /// - Parameter credentialStore: The credential store to use for Keychain access
    init(credentialStore: CredentialStore) {
        self.credentialStore = credentialStore
    }

    // MARK: - DiscourseAPIKeyProvider

    func getAPIKey() async throws -> DiscourseCredential {
        guard let jsonString = try credentialStore.get(forKey: DiscourseAuthManager.discourseCredentialKey),
              let data = jsonString.data(using: .utf8) else {
            throw DiscourseAuthError.notAuthenticated
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(DiscourseCredential.self, from: data)
        } catch {
            throw DiscourseAuthError.notAuthenticated
        }
    }

    func hasValidCredential() -> Bool {
        return credentialStore.contains(key: DiscourseAuthManager.discourseCredentialKey)
    }

    func clearCredential() {
        try? credentialStore.delete(forKey: DiscourseAuthManager.discourseCredentialKey)
    }
}
