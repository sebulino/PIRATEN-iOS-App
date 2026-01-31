//
//  TokenRefresher.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

/// Protocol for refreshing OAuth2/OIDC access tokens.
/// Implementations should use refresh tokens to obtain new access tokens
/// without requiring user re-authentication.
protocol TokenRefresher: Sendable {
    /// Refreshes the access token using a refresh token.
    /// - Parameters:
    ///   - refreshToken: The refresh token to use for obtaining new tokens
    ///   - configuration: The OIDC configuration containing the token endpoint
    /// - Returns: A new token bundle with fresh access token
    /// - Throws: AuthError.refreshFailed if refresh fails
    func refresh(
        refreshToken: String,
        configuration: OIDCConfiguration
    ) async throws -> OIDCTokenBundle
}

// Note: AuthError.refreshFailed case is defined in AuthState.swift
