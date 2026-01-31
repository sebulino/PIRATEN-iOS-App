//
//  AppAuthOIDCDiscoveryService.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation
import AppAuth

/// OIDC discovery service implementation using AppAuth-iOS.
/// Fetches OIDC configuration from the issuer's /.well-known/openid-configuration endpoint.
final class AppAuthOIDCDiscoveryService: OIDCDiscoveryService, @unchecked Sendable {
    private let issuerURL: URL

    /// Initializes the discovery service with the OIDC issuer URL.
    /// - Parameter issuerURL: The base URL of the OIDC provider (e.g., https://sso.piratenpartei.de/realms/Piratenlogin)
    init(issuerURL: URL) {
        self.issuerURL = issuerURL
    }

    /// Discovers OIDC configuration from the issuer using AppAuth's built-in discovery.
    /// AppAuth fetches /.well-known/openid-configuration and populates OIDServiceConfiguration.
    /// - Returns: The discovered OIDC configuration
    /// - Throws: AuthError.discoveryFailed if discovery fails
    func discoverConfiguration() async throws -> OIDCConfiguration {
        try await withCheckedThrowingContinuation { continuation in
            OIDAuthorizationService.discoverConfiguration(forIssuer: issuerURL) { configuration, error in
                if let error = error {
                    let message = error.localizedDescription
                    continuation.resume(throwing: AuthError.discoveryFailed(message))
                    return
                }

                guard let config = configuration else {
                    continuation.resume(throwing: AuthError.discoveryFailed("Keine Konfiguration erhalten"))
                    return
                }

                // Map AppAuth's OIDServiceConfiguration to our domain model
                // Note: OIDServiceConfiguration provides authorizationEndpoint and tokenEndpoint.
                // Additional endpoints (userinfo, end_session) are available via discoveryDocument.
                let discoveryDoc = config.discoveryDocument

                let oidcConfig = OIDCConfiguration(
                    issuer: config.issuer ?? self.issuerURL,
                    authorizationEndpoint: config.authorizationEndpoint,
                    tokenEndpoint: config.tokenEndpoint,
                    userinfoEndpoint: discoveryDoc?.userinfoEndpoint,
                    endSessionEndpoint: config.endSessionEndpoint,
                    jwksURI: discoveryDoc?.jwksURL
                )

                continuation.resume(returning: oidcConfig)
            }
        }
    }
}
