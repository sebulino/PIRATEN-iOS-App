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
    private var isAuthenticated = false

    func authenticate() async -> Result<Void, AuthError> {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        isAuthenticated = true
        return .success(())
    }

    func logout() async {
        isAuthenticated = false
    }

    func hasValidSession() async -> Bool {
        return isAuthenticated
    }
}
