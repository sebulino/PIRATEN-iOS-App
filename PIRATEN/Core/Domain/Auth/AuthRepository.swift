//
//  AuthRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Protocol defining the authentication repository interface.
/// This abstraction allows swapping real SSO implementation later without UI changes.
@MainActor
protocol AuthRepository {
    /// Attempts to authenticate the user.
    /// - Returns: Result indicating success or failure with AuthError
    func authenticate() async -> Result<Void, AuthError>

    /// Logs out the current user.
    func logout() async

    /// Checks if a valid session exists.
    /// - Returns: true if authenticated, false otherwise
    func hasValidSession() async -> Bool

    /// Retrieves a valid access token, refreshing if necessary.
    /// - Returns: A valid access token, or nil if not authenticated or refresh fails
    /// - Throws: AuthError if refresh fails due to revoked/expired refresh token
    ///
    /// Use this method before making authenticated API calls.
    /// If the access token is expired but a refresh token is available,
    /// this will automatically attempt to refresh the token.
    func getValidAccessToken() async throws -> String?

    /// Retrieves the current authenticated user's information.
    /// - Returns: User if authenticated, nil otherwise
    ///
    /// Note: Currently returns PLACEHOLDER DATA for development.
    /// Real user information will come from Piratenlogin SSO once integrated.
    func getCurrentUser() async -> User?
}
