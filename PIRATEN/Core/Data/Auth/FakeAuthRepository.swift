//
//  FakeAuthRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Fake implementation of AuthRepository for development and testing.
/// Will be replaced by real SSO implementation in future milestones.
@MainActor
final class FakeAuthRepository: AuthRepository {

    /// Key used to store the authentication token in the credential store
    private static let tokenKey = "auth_token"

    /// Credential store for persisting tokens
    private let credentialStore: CredentialStore

    /// Initializes the fake auth repository with a credential store.
    /// - Parameter credentialStore: The credential store to use for token persistence
    init(credentialStore: CredentialStore) {
        self.credentialStore = credentialStore
    }

    func authenticate() async -> Result<Void, AuthError> {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Store a dummy token (non-sensitive, for development only)
        // This simulates what real SSO will do with actual tokens
        let dummyToken = "fake_session_\(UUID().uuidString)"
        do {
            try credentialStore.set(dummyToken, forKey: Self.tokenKey)
        } catch {
            return .failure(.unknown("Failed to store credentials"))
        }

        return .success(())
    }

    func logout() async {
        // Remove the stored token
        try? credentialStore.delete(forKey: Self.tokenKey)
    }

    func hasValidSession() async -> Bool {
        // Check if a token exists in the credential store
        return credentialStore.contains(key: Self.tokenKey)
    }
}
