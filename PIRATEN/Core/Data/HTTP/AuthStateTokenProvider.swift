//
//  AuthStateTokenProvider.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

/// Error thrown when no valid access token is available
enum TokenProviderError: Error {
    case notAuthenticated
}

/// Adapts AuthStateManager to the TokenProvider protocol.
/// This allows the AuthenticatedHTTPClient to get tokens from the auth system.
@MainActor
final class AuthStateTokenProvider: TokenProvider {
    private let authStateManager: AuthStateManager

    init(authStateManager: AuthStateManager) {
        self.authStateManager = authStateManager
    }

    nonisolated func getValidAccessToken() async throws -> String {
        // Hop to main actor since authStateManager is @MainActor isolated
        try await self.fetchToken()
    }

    @MainActor
    private func fetchToken() async throws -> String {
        guard let token = await authStateManager.getValidAccessToken() else {
            throw TokenProviderError.notAuthenticated
        }
        return token
    }
}
