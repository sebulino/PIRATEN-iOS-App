//
//  AuthStateManager.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation
import Combine

/// Manages the authentication state of the application.
/// This is the ViewModel layer that coordinates between UI and domain.
/// It depends on AuthRepository protocol, not concrete implementations.
@MainActor
final class AuthStateManager: ObservableObject {
    @Published private(set) var currentState: AuthState = .unauthenticated

    private let authRepository: AuthRepository

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    /// Initiates the authentication flow
    func authenticate() {
        currentState = .authenticating

        Task {
            let result = await authRepository.authenticate()
            switch result {
            case .success:
                currentState = .authenticated
            case .failure(let error):
                currentState = .failed(error)
            }
        }
    }

    /// Performs logout
    func logout() {
        Task {
            await authRepository.logout()
            currentState = .unauthenticated
        }
    }

    /// Checks for existing valid session on app launch
    func checkExistingSession() {
        Task {
            if await authRepository.hasValidSession() {
                currentState = .authenticated
            }
        }
    }
}
