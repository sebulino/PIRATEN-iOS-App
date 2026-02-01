//
//  FakeAuthRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Fake implementation of AuthRepository for development and testing.
/// Will be replaced by real SSO implementation in future milestones.
///
/// IMPORTANT: All user data returned by this repository is PLACEHOLDER DATA
/// for development and UI testing purposes only. Real user information will
/// come from Piratenlogin SSO once integrated.
@MainActor
final class FakeAuthRepository: AuthRepository {

    /// Key used to store the authentication token in the credential store
    private static let tokenKey = "auth_token"

    /// Credential store for persisting tokens
    private let credentialStore: CredentialStore

    // MARK: - Stub User Data (PLACEHOLDER)

    /// Static fake user for development and UI testing.
    /// This data is NOT real and will be replaced by SSO user info.
    private let stubUser = User(
        id: "fake-user-12345",
        username: "maria.piratin",
        displayName: "Maria Beispiel",
        email: "maria.beispiel@piratenpartei.de",
        avatarUrl: nil,
        memberSince: Calendar.current.date(from: DateComponents(year: 2019, month: 3, day: 15)),
        localGroupName: "Kreisverband München",
        stateAssociationName: "Landesverband Bayern"
    )

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

    func getValidAccessToken() async throws -> String? {
        // Return the stored token if it exists (fake implementation doesn't refresh)
        guard credentialStore.contains(key: Self.tokenKey) else {
            return nil
        }
        return try credentialStore.get(forKey: Self.tokenKey)
    }

    func getCurrentUser() async -> User? {
        // Return stub user only if authenticated (placeholder behavior)
        guard await hasValidSession() else {
            return nil
        }
        return stubUser
    }
}
