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
///
/// ## Auth Error Handling (M3B-006)
/// When a 401/403 response is received from the server:
/// 1. A single re-auth transition is triggered (no retries)
/// 2. The state transitions to `.sessionExpired` with a clear message
/// 3. Concurrent auth error callbacks are ignored (single-attempt rule)
///
/// This prevents infinite refresh loops when multiple API calls fail simultaneously.
/// See: Docs/DECISIONS.md D-009 for rationale.
@MainActor
final class AuthStateManager: ObservableObject {
    @Published private(set) var currentState: AuthState = .unauthenticated

    private let authRepository: AuthRepository

    /// Guards against concurrent auth error handling.
    /// When true, subsequent auth error callbacks are ignored.
    /// Reset when user successfully re-authenticates or logs out explicitly.
    private var isHandlingAuthError: Bool = false

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    /// Initiates the authentication flow.
    /// Resets the auth error guard on successful authentication.
    func authenticate() {
        currentState = .authenticating

        Task {
            let result = await authRepository.authenticate()
            switch result {
            case .success:
                // Reset the auth error guard on successful login
                isHandlingAuthError = false
                currentState = .authenticated
            case .failure(let error):
                currentState = .failed(error)
            }
        }
    }

    /// Performs logout.
    /// Resets the auth error guard to allow fresh authentication.
    func logout() {
        Task {
            await authRepository.logout()
            // Reset the auth error guard on explicit logout
            isHandlingAuthError = false
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

    /// Requests a valid access token, refreshing if necessary.
    /// If refresh fails, transitions to unauthenticated state.
    /// - Returns: A valid access token, or nil if not authenticated
    func getValidAccessToken() async -> String? {
        do {
            return try await authRepository.getValidAccessToken()
        } catch {
            // Token refresh failed - session is no longer valid
            // Transition to unauthenticated with a clear error message
            await authRepository.logout()
            currentState = .failed(
                AuthError.refreshFailed("Sitzung abgelaufen - bitte erneut anmelden")
            )
            return nil
        }
    }

    /// Handles authentication errors from API calls (401/403 responses).
    /// Call this when an API returns 401/403 to trigger re-auth flow.
    ///
    /// ## Single-Attempt Rule (M3B-006)
    /// This method uses a guard flag to prevent infinite loops:
    /// - First call: logs out user and transitions to `.sessionExpired`
    /// - Subsequent calls (while flag is set): ignored silently
    /// - Flag is reset when user successfully re-authenticates or logs out explicitly
    ///
    /// This prevents cascading failures when multiple concurrent API calls
    /// all receive 401/403 and try to trigger re-auth simultaneously.
    func handleAuthenticationError() {
        Task {
            // Single-attempt guard: ignore if already handling an auth error
            guard !isHandlingAuthError else {
                return
            }

            // Set the guard to prevent concurrent handling
            isHandlingAuthError = true

            // Log out and clear credentials
            await authRepository.logout()

            // Transition to session expired state with clear user message
            currentState = .sessionExpired
        }
    }
}
