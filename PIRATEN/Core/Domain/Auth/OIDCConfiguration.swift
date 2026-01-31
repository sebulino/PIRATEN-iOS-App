//
//  OIDCConfiguration.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

/// Holds the discovered OIDC endpoints and configuration.
/// These values are obtained via OIDC discovery (/.well-known/openid-configuration).
struct OIDCConfiguration: Sendable {
    let issuer: URL
    let authorizationEndpoint: URL
    let tokenEndpoint: URL
    let userinfoEndpoint: URL?
    let endSessionEndpoint: URL?
    let jwksURI: URL?
}

/// Protocol for OIDC discovery service.
/// Implementations should fetch configuration from the issuer's discovery document.
protocol OIDCDiscoveryService: Sendable {
    /// Discovers OIDC configuration from the issuer.
    /// - Returns: The discovered OIDC configuration
    /// - Throws: AuthError.discoveryFailed if discovery fails
    func discoverConfiguration() async throws -> OIDCConfiguration
}
