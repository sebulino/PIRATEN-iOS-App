//
//  AppAuthOIDCAuthService.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation
import AppAuth
import UIKit

/// AppAuth-iOS implementation of OIDCAuthService.
/// Handles OAuth2/OIDC authorization using authorization code flow with PKCE.
final class AppAuthOIDCAuthService: NSObject, OIDCAuthService, @unchecked Sendable {

    /// Client ID for the OAuth2 application (public client, no secret needed for native apps)
    private let clientID: String

    /// Redirect URI that the authorization server will redirect to after authentication
    private let redirectURI: URL

    /// Scopes to request during authorization
    private let scopes: [String]

    /// Current authorization flow session (must be retained during the flow)
    private var currentAuthorizationFlow: OIDExternalUserAgentSession?

    /// Continuation for async/await bridge
    private var authorizationContinuation: CheckedContinuation<OIDCTokenBundle, Error>?

    /// Initializes the auth service with OAuth2 client configuration.
    /// - Parameters:
    ///   - clientID: The OAuth2 client ID registered with the authorization server
    ///   - redirectURI: The redirect URI registered with the authorization server
    ///   - scopes: OAuth2 scopes to request (defaults to openid, profile, offline_access)
    init(
        clientID: String,
        redirectURI: URL,
        scopes: [String] = [OIDScopeOpenID, OIDScopeProfile, "offline_access"]
    ) {
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.scopes = scopes
        super.init()
    }

    /// Performs the OIDC authorization flow using AppAuth.
    /// This uses ASWebAuthenticationSession under the hood for secure browser-based auth.
    /// - Parameter configuration: The discovered OIDC configuration
    /// - Returns: Token bundle containing access token, refresh token, and ID token
    /// - Throws: AuthError on failure or user cancellation
    @MainActor
    func authorize(with configuration: OIDCConfiguration) async throws -> OIDCTokenBundle {
        // Build AppAuth service configuration from our domain model
        let serviceConfig = OIDServiceConfiguration(
            authorizationEndpoint: configuration.authorizationEndpoint,
            tokenEndpoint: configuration.tokenEndpoint,
            issuer: configuration.issuer,
            registrationEndpoint: nil,
            endSessionEndpoint: configuration.endSessionEndpoint
        )

        // Build the authorization request with PKCE (automatic in AppAuth)
        let request = OIDAuthorizationRequest(
            configuration: serviceConfig,
            clientId: clientID,
            clientSecret: nil, // Public client - no secret for native apps (RFC 8252)
            scopes: scopes,
            redirectURL: redirectURI,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil
        )

        // Get the presenting view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.unknown("Kein Fenster zum Anzeigen der Anmeldung gefunden")
        }

        // Find the topmost presented view controller
        var presentingVC = rootViewController
        while let presented = presentingVC.presentedViewController {
            presentingVC = presented
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.authorizationContinuation = continuation

            // Start the authorization flow
            // AppAuth handles PKCE automatically and uses ASWebAuthenticationSession
            self.currentAuthorizationFlow = OIDAuthState.authState(
                byPresenting: request,
                presenting: presentingVC
            ) { [weak self] authState, error in
                guard let self = self else { return }

                self.currentAuthorizationFlow = nil

                if let error = error {
                    let nsError = error as NSError
                    // Check for user cancellation
                    if nsError.domain == OIDGeneralErrorDomain &&
                       nsError.code == OIDErrorCode.userCanceledAuthorizationFlow.rawValue {
                        self.authorizationContinuation?.resume(throwing: AuthError.cancelled)
                    } else {
                        self.authorizationContinuation?.resume(
                            throwing: AuthError.tokenError(error.localizedDescription)
                        )
                    }
                    self.authorizationContinuation = nil
                    return
                }

                guard let authState = authState,
                      let tokenResponse = authState.lastTokenResponse,
                      let accessToken = tokenResponse.accessToken else {
                    self.authorizationContinuation?.resume(
                        throwing: AuthError.tokenError("Keine Token in der Antwort erhalten")
                    )
                    self.authorizationContinuation = nil
                    return
                }

                let tokenBundle = OIDCTokenBundle(
                    accessToken: accessToken,
                    refreshToken: tokenResponse.refreshToken,
                    idToken: tokenResponse.idToken,
                    accessTokenExpirationDate: tokenResponse.accessTokenExpirationDate
                )

                self.authorizationContinuation?.resume(returning: tokenBundle)
                self.authorizationContinuation = nil
            }
        }
    }

    /// Resumes the authorization flow after receiving a redirect URL.
    /// This must be called from the app's URL handling code.
    /// - Parameter url: The redirect URL received by the app
    /// - Returns: true if the URL was handled by the current authorization flow
    func resumeAuthorizationFlow(with url: URL) -> Bool {
        guard let flow = currentAuthorizationFlow else {
            return false
        }
        return flow.resumeExternalUserAgentFlow(with: url)
    }
}
