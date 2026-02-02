//
//  DiscourseAuthCoordinator.swift
//  PIRATEN
//
//  Created by Claude Code on 02.02.26.
//

import AuthenticationServices
import Combine
import Foundation
import SwiftUI

/// State of the Discourse authentication process
enum DiscourseAuthState: Equatable {
    /// No authentication in progress
    case idle

    /// Authentication is in progress
    case authenticating

    /// Authentication completed successfully
    case authenticated

    /// Authentication failed with error
    case failed(message: String)
}

/// Coordinates the Discourse User API Key authentication flow.
/// This class manages the entire auth process from checking if auth is needed
/// to completing the auth flow and storing the credential.
///
/// ## Usage
/// 1. Check `needsAuthentication` to see if auth is required
/// 2. Call `authenticate(from:)` to start the auth flow
/// 3. Observe `authState` for progress updates
/// 4. After success, retry the failed Discourse API call
@MainActor
final class DiscourseAuthCoordinator: NSObject, ObservableObject {

    // MARK: - Published State

    /// Current state of the authentication process
    @Published private(set) var authState: DiscourseAuthState = .idle

    // MARK: - Dependencies

    private let discourseAuthManager: DiscourseAuthManager?
    private let discourseAPIKeyProvider: DiscourseAPIKeyProvider
    private let credentialStore: CredentialStore

    // MARK: - Initialization

    /// Creates a DiscourseAuthCoordinator with the required dependencies.
    /// - Parameters:
    ///   - discourseAuthManager: Manager for the auth flow (nil if config missing)
    ///   - discourseAPIKeyProvider: Provider to check for existing credentials
    ///   - credentialStore: Store for saving the credential after auth
    init(
        discourseAuthManager: DiscourseAuthManager?,
        discourseAPIKeyProvider: DiscourseAPIKeyProvider,
        credentialStore: CredentialStore
    ) {
        self.discourseAuthManager = discourseAuthManager
        self.discourseAPIKeyProvider = discourseAPIKeyProvider
        self.credentialStore = credentialStore
        super.init()
    }

    // MARK: - Public Interface

    /// Whether Discourse authentication is needed.
    /// Returns true if no valid credential is stored.
    var needsAuthentication: Bool {
        !discourseAPIKeyProvider.hasValidCredential()
    }

    /// Whether Discourse authentication is available.
    /// Returns false if the DiscourseAuthManager couldn't be initialized (missing config).
    var isAuthAvailable: Bool {
        discourseAuthManager != nil
    }

    /// Starts the Discourse User API Key authentication flow.
    /// Opens a browser for the user to authenticate and approve the API key.
    ///
    /// - Parameter window: The window to present the auth session from
    func authenticate(from window: UIWindow?) async {
        guard let authManager = discourseAuthManager else {
            authState = .failed(message: "Discourse-Authentifizierung ist nicht konfiguriert")
            return
        }

        guard let window = window else {
            authState = .failed(message: "Kein Fenster für Authentifizierung verfügbar")
            return
        }

        authState = .authenticating

        do {
            // Create presentation context
            let contextProvider = WindowPresentationContextProvider(window: window)

            // Start the auth flow (opens browser)
            let result = try await authManager.authenticate(
                presentationContextProvider: contextProvider
            )

            // Complete authentication (decrypt payload, verify nonce, store credential)
            _ = try authManager.completeAuthentication(
                encryptedPayload: result.encryptedPayload,
                credentialStore: credentialStore
            )

            authState = .authenticated

        } catch DiscourseAuthError.authSessionCancelled {
            authState = .failed(message: "Authentifizierung abgebrochen")
        } catch let error as DiscourseAuthError {
            authState = .failed(message: mapErrorToMessage(error))
        } catch {
            authState = .failed(message: "Unbekannter Fehler bei der Authentifizierung")
        }
    }

    /// Resets the auth state to idle.
    /// Call this before retrying authentication.
    func reset() {
        authState = .idle
    }

    // MARK: - Private Helpers

    private func mapErrorToMessage(_ error: DiscourseAuthError) -> String {
        switch error {
        case .missingConfiguration(let key):
            return "Fehlende Konfiguration: \(key)"
        case .invalidURL:
            return "Ungültige Authentifizierungs-URL"
        case .nonceGenerationFailed:
            return "Sicherheitsprüfung fehlgeschlagen"
        case .invalidPublicKey:
            return "Ungültiger Schlüssel"
        case .authSessionCancelled:
            return "Authentifizierung abgebrochen"
        case .authSessionFailed(let message):
            return "Authentifizierung fehlgeschlagen: \(message)"
        case .callbackMissingPayload:
            return "Keine Antwort vom Server"
        case .invalidCallbackURL:
            return "Ungültige Rückgabe-URL"
        case .invalidPayload:
            return "Ungültige Server-Antwort"
        case .missingPrivateKey:
            return "Schlüssel nicht gefunden"
        case .nonceMismatch:
            return "Sicherheitsprüfung fehlgeschlagen"
        case .decryptionFailed:
            return "Entschlüsselung fehlgeschlagen"
        case .notAuthenticated:
            return "Nicht authentifiziert"
        }
    }
}

// MARK: - Presentation Context Provider

/// Provides the window for ASWebAuthenticationSession presentation.
private final class WindowPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let window: UIWindow

    init(window: UIWindow) {
        self.window = window
        super.init()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        window
    }
}
