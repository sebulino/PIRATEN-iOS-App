//
//  OIDCAuthRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

/// Real implementation of AuthRepository using OIDC/OAuth2.
/// Coordinates between OIDC discovery, authorization, and token storage.
@MainActor
final class OIDCAuthRepository: AuthRepository {

    // MARK: - Dependencies

    private let discoveryService: OIDCDiscoveryService
    private let authService: OIDCAuthService
    private let credentialStore: CredentialStore

    // MARK: - Storage Keys

    private static let accessTokenKey = "oidc_access_token"
    private static let refreshTokenKey = "oidc_refresh_token"
    private static let idTokenKey = "oidc_id_token"
    private static let tokenExpirationKey = "oidc_token_expiration"

    // MARK: - Cached State

    /// Cached OIDC configuration from discovery
    private var cachedConfiguration: OIDCConfiguration?

    // MARK: - Initialization

    /// Initializes the OIDC auth repository with required dependencies.
    /// - Parameters:
    ///   - discoveryService: Service for OIDC discovery
    ///   - authService: Service for OAuth authorization flow
    ///   - credentialStore: Secure storage for tokens
    init(
        discoveryService: OIDCDiscoveryService,
        authService: OIDCAuthService,
        credentialStore: CredentialStore
    ) {
        self.discoveryService = discoveryService
        self.authService = authService
        self.credentialStore = credentialStore
    }

    // MARK: - AuthRepository Protocol

    func authenticate() async -> Result<Void, AuthError> {
        do {
            // Step 1: Discover OIDC configuration
            let configuration = try await getOrDiscoverConfiguration()

            // Step 2: Perform authorization flow
            let tokenBundle = try await authService.authorize(with: configuration)

            // Step 3: Store tokens securely
            try storeTokens(tokenBundle)

            return .success(())
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.unknown(error.localizedDescription))
        }
    }

    func logout() async {
        // Clear all stored tokens
        try? credentialStore.delete(forKey: Self.accessTokenKey)
        try? credentialStore.delete(forKey: Self.refreshTokenKey)
        try? credentialStore.delete(forKey: Self.idTokenKey)
        try? credentialStore.delete(forKey: Self.tokenExpirationKey)
    }

    func hasValidSession() async -> Bool {
        // Check if we have an access token
        guard credentialStore.contains(key: Self.accessTokenKey) else {
            return false
        }

        // Check if token is expired (if we have expiration info)
        if let expirationString = try? credentialStore.get(forKey: Self.tokenExpirationKey),
           let expirationTimestamp = Double(expirationString) {
            let expirationDate = Date(timeIntervalSince1970: expirationTimestamp)
            // Consider session invalid if token expires within 60 seconds
            if expirationDate.timeIntervalSinceNow < 60 {
                // Token is expired or about to expire
                // Future: attempt refresh here
                return credentialStore.contains(key: Self.refreshTokenKey)
            }
        }

        return true
    }

    func getCurrentUser() async -> User? {
        // Return placeholder user if authenticated
        // Real user info will come from userinfo endpoint or ID token claims in future milestone
        guard await hasValidSession() else {
            return nil
        }

        // Placeholder user - will be replaced with real user info from ID token/userinfo
        return User(
            id: "oidc-user",
            username: "authenticated-user",
            displayName: "Authentifizierter Benutzer",
            email: "user@piratenpartei.de", // Placeholder until ID token parsing
            avatarUrl: nil,
            memberSince: nil,
            localGroupName: nil,
            stateAssociationName: nil
        )
    }

    // MARK: - Private Helpers

    /// Gets cached OIDC configuration or discovers it if not available.
    private func getOrDiscoverConfiguration() async throws -> OIDCConfiguration {
        if let cached = cachedConfiguration {
            return cached
        }

        let configuration = try await discoveryService.discoverConfiguration()
        cachedConfiguration = configuration
        return configuration
    }

    /// Stores tokens securely in the credential store.
    /// - Parameter tokenBundle: The tokens to store
    private func storeTokens(_ tokenBundle: OIDCTokenBundle) throws {
        // Store access token (required)
        try credentialStore.set(tokenBundle.accessToken, forKey: Self.accessTokenKey)

        // Store refresh token if available
        if let refreshToken = tokenBundle.refreshToken {
            try credentialStore.set(refreshToken, forKey: Self.refreshTokenKey)
        }

        // Store ID token if available
        if let idToken = tokenBundle.idToken {
            try credentialStore.set(idToken, forKey: Self.idTokenKey)
        }

        // Store expiration date if available
        if let expirationDate = tokenBundle.accessTokenExpirationDate {
            let timestamp = String(expirationDate.timeIntervalSince1970)
            try credentialStore.set(timestamp, forKey: Self.tokenExpirationKey)
        }
    }
}
