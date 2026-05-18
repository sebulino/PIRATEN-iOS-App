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
    private let recentRecipientsStorage: RecentRecipientsStorage?

    /// Guards against concurrent auth error handling.
    /// When true, subsequent auth error callbacks are ignored.
    /// Reset when user successfully re-authenticates or logs out explicitly.
    private var isHandlingAuthError: Bool = false

    init(authRepository: AuthRepository, recentRecipientsStorage: RecentRecipientsStorage? = nil) {
        self.authRepository = authRepository
        self.recentRecipientsStorage = recentRecipientsStorage
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
    /// Clears user-specific local data (recent recipients).
    func logout() {
        Task {
            await authRepository.logout()
            // Clear user-specific local data
            recentRecipientsStorage?.clearAll()
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
    /// - Returns: A valid access token, or nil if the session cannot be renewed.
    ///
    /// The meine-piraten.de access token is short-lived (5 minutes per the
    /// API contract). On expiry, `authRepository.getValidAccessToken()`
    /// refreshes via the SSO provider's refresh token. If that refresh
    /// throws — which happens when the refresh token itself is revoked or
    /// expired — the session is genuinely gone. Route through the central
    /// `handleAuthenticationError()` rather than inlining the transition,
    /// so the single-attempt guard works across both failure paths
    /// (local refresh fail vs. server 401) and the UI lands on the same
    /// `.sessionExpired` state.
    func getValidAccessToken() async -> String? {
        do {
            return try await authRepository.getValidAccessToken()
        } catch {
            handleAuthenticationError()
            return nil
        }
    }

    /// Handles authentication errors from PiratenSSO-authenticated API calls
    /// (currently only meine-piraten.de; Discourse uses User API Key auth on a
    /// separate path and does NOT route through here, per ADR-0009).
    ///
    /// Called from `AuthenticatedHTTPClient` when the server returns 401 or 403.
    /// In practice on meine-piraten.de, both status codes indicate the SSO
    /// session is no longer accepted — 403 for "permission denied" is rare to
    /// non-existent for an SSO-authenticated user, and the `TodoAPIError`
    /// layer collapses them to a single `.unauthorized` case anyway.
    ///
    /// Uses a single-attempt guard (`isHandlingAuthError`) so a burst of
    /// simultaneous 401s from parallel API calls only triggers one logout
    /// transition, not one per failing request. The guard is reset when the
    /// user successfully re-authenticates or logs out explicitly.
    ///
    /// Transitions to `.sessionExpired` (a distinct AuthState case, not just
    /// `.unauthenticated`) so the UI can show a "session expired, please log
    /// in again" message via `SessionExpiredView` rather than the generic
    /// initial-launch login screen.
    ///
    /// Related: OPEN-09 (#72), FR-AUTH-004, ADR-0009.
    func handleAuthenticationError() {
        guard !isHandlingAuthError else { return }
        isHandlingAuthError = true

        Task {
            await authRepository.logout()
            recentRecipientsStorage?.clearAll()
            currentState = .sessionExpired
        }
    }
}
