//
//  AppAuthTokenRefresher.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation
import AppAuth

/// AppAuth-iOS implementation of TokenRefresher.
/// Uses AppAuth's token endpoint support to perform RFC 6749 token refresh.
final class AppAuthTokenRefresher: TokenRefresher, @unchecked Sendable {

    /// Client ID for the OAuth2 application
    private let clientID: String

    /// Initializes the token refresher with the OAuth2 client ID.
    /// - Parameter clientID: The OAuth2 client ID (public client, no secret needed)
    init(clientID: String) {
        self.clientID = clientID
    }

    /// Refreshes the access token using AppAuth's token request mechanism.
    /// This performs a standard OAuth2 refresh_token grant request.
    /// - Parameters:
    ///   - refreshToken: The refresh token to use
    ///   - configuration: OIDC configuration containing the token endpoint
    /// - Returns: New token bundle with refreshed access token
    /// - Throws: AuthError if refresh fails (token revoked, network error, etc.)
    func refresh(
        refreshToken: String,
        configuration: OIDCConfiguration
    ) async throws -> OIDCTokenBundle {
        // Build AppAuth service configuration from our domain model
        let serviceConfig = OIDServiceConfiguration(
            authorizationEndpoint: configuration.authorizationEndpoint,
            tokenEndpoint: configuration.tokenEndpoint,
            issuer: configuration.issuer,
            registrationEndpoint: nil,
            endSessionEndpoint: configuration.endSessionEndpoint
        )

        // Build the token refresh request
        let tokenRequest = OIDTokenRequest(
            configuration: serviceConfig,
            grantType: OIDGrantTypeRefreshToken,
            authorizationCode: nil,
            redirectURL: nil,
            clientID: clientID,
            clientSecret: nil, // Public client - no secret
            scope: nil, // Use original scopes from refresh token
            refreshToken: refreshToken,
            codeVerifier: nil,
            additionalParameters: nil
        )

        return try await withCheckedThrowingContinuation { continuation in
            OIDAuthorizationService.perform(tokenRequest) { tokenResponse, error in
                if let error = error {
                    let nsError = error as NSError

                    // Check for specific OAuth errors that indicate token is invalid/revoked
                    if nsError.domain == OIDOAuthTokenErrorDomain {
                        // OAuth token errors (invalid_grant, etc.) mean the refresh token is bad
                        continuation.resume(
                            throwing: AuthError.refreshFailed("Sitzung abgelaufen - bitte erneut anmelden")
                        )
                    } else if nsError.domain == OIDGeneralErrorDomain {
                        // General errors (network, etc.)
                        continuation.resume(
                            throwing: AuthError.networkError(error.localizedDescription)
                        )
                    } else {
                        continuation.resume(
                            throwing: AuthError.refreshFailed(error.localizedDescription)
                        )
                    }
                    return
                }

                guard let response = tokenResponse,
                      let accessToken = response.accessToken else {
                    continuation.resume(
                        throwing: AuthError.refreshFailed("Keine Token in der Antwort erhalten")
                    )
                    return
                }

                let tokenBundle = OIDCTokenBundle(
                    accessToken: accessToken,
                    // Refresh tokens may or may not be rotated by the server
                    refreshToken: response.refreshToken ?? refreshToken,
                    idToken: response.idToken,
                    accessTokenExpirationDate: response.accessTokenExpirationDate
                )

                continuation.resume(returning: tokenBundle)
            }
        }
    }
}
