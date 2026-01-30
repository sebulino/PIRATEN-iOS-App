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
}
