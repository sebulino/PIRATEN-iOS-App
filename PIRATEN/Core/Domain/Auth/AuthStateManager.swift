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

    /// Checks for existing valid session on app launch.
    /// Actually validates the session by attempting to get a valid token,
    /// not just checking if tokens exist.
    func checkExistingSession() {
        Task {
            // First check if we have any session at all
            guard await authRepository.hasValidSession() else {
                // No tokens - stay unauthenticated
                return
            }

            // Try to get a valid token (this will refresh if needed)
            do {
                if let _ = try await authRepository.getValidAccessToken() {
                    // Token is valid (or was successfully refreshed)
                    currentState = .authenticated
                }
                // If nil, no tokens exist - stay unauthenticated
            } catch {
                // Token refresh failed - session is invalid
                // Clear stale tokens and stay unauthenticated
                await authRepository.logout()
                // Don't set failed state here - just stay unauthenticated
                // User will see login screen naturally
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
            // Clear tokens and return to unauthenticated state
            // User will see login screen and can try again
            await authRepository.logout()
            currentState = .unauthenticated
            return nil
        }
    }

    /// Handles authentication errors from API calls (401/403 responses).
    ///
    /// NOTE: This method is currently disabled. With onAuthError: nil for the Discourse
    /// HTTP client, there is no caller for this method. Discourse 401/403 errors are
    /// handled locally in the views without triggering session expiration.
    ///
    /// When proper Discourse auth is implemented (see Q-002), this can be re-enabled
    /// for actual SSO session expiration scenarios.
    func handleAuthenticationError() {
        // DISABLED: No-op to prevent accidental session expiration
        // If this is being called, there's a bug - we should debug rather than
        // silently expire the session
        print("WARNING: handleAuthenticationError() called but is disabled")
    }
}
