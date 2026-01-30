//
//  AuthStateManager.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation
import Combine

/// Manages the authentication state of the application
@MainActor
final class AuthStateManager: ObservableObject {
    @Published private(set) var currentState: AppState = .loggedOut

    /// Performs fake login (toggles between loggedOut and loggedIn)
    func performFakeLogin() {
        currentState = .loggingIn

        // Simulate async login
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            currentState = .loggedIn
        }
    }

    /// Performs logout
    func logout() {
        currentState = .loggedOut
    }
}
