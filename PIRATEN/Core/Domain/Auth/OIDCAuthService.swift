//
//  OIDCAuthService.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

/// Result of a successful OIDC authorization containing the token bundle.
struct OIDCTokenBundle: Sendable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let accessTokenExpirationDate: Date?
}

/// Protocol for OIDC authorization service.
/// Implementations handle the OAuth2/OIDC authorization flow (authorization code + PKCE).
protocol OIDCAuthService: Sendable {
    /// Performs the OIDC authorization flow.
    /// - Parameter configuration: The discovered OIDC configuration
    /// - Returns: Token bundle on success
    /// - Throws: AuthError on failure or cancellation
    func authorize(with configuration: OIDCConfiguration) async throws -> OIDCTokenBundle

    /// Resumes the authorization flow after redirect.
    /// Call this when the app receives a redirect URL.
    /// - Parameter url: The redirect URL received by the app
    /// - Returns: true if the URL was handled, false otherwise
    func resumeAuthorizationFlow(with url: URL) -> Bool
}
