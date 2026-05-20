//
//  DiscourseHTTPClient.swift
//  PIRATEN
//
//  Created by Claude Code on 02.02.26.
//

import Foundation

/// HTTP client that automatically injects Discourse User API Key authentication headers.
/// Wraps a base HTTPClient and adds User-Api-Key and User-Api-Client-Id headers
/// to all requests using the stored credential.
///
/// ## Usage
/// This client should be used for all Discourse API requests after successful authentication.
/// If no credential is stored, requests will fail with notAuthenticated error.
///
/// ## Headers Added
/// - `User-Api-Key`: The Discourse User API Key
/// - `User-Api-Client-Id`: The client ID that requested the key
///
/// Reference: https://meta.discourse.org/t/user-api-keys-specification/48536
final class DiscourseHTTPClient: HTTPClient, @unchecked Sendable {

    // MARK: - Dependencies

    private let baseClient: HTTPClient
    private let apiKeyProvider: DiscourseAPIKeyProvider

    // MARK: - Initialization

    /// Creates a new DiscourseHTTPClient.
    /// - Parameters:
    ///   - baseClient: The underlying HTTP client for executing requests
    ///   - apiKeyProvider: Provider for Discourse API key credentials
    init(baseClient: HTTPClient, apiKeyProvider: DiscourseAPIKeyProvider) {
        self.baseClient = baseClient
        self.apiKeyProvider = apiKeyProvider
    }

    // MARK: - HTTPClient

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        // Get the credential (throws if not authenticated)
        let credential = try await apiKeyProvider.getAPIKey()

        // Add Discourse auth headers to the request
        var headers = request.headers
        headers["User-Api-Key"] = credential.apiKey
        headers["User-Api-Client-Id"] = credential.clientId

        // Create authenticated request
        let authenticatedRequest = HTTPRequest(
            url: request.url,
            method: request.method,
            headers: headers,
            body: request.body
        )

        let response = try await baseClient.execute(authenticatedRequest)

        // If the server rejects the API key (revoked by admin), clear the stored credential
        // so the app falls back to the .notAuthenticated state for re-auth
        if response.statusCode == 401 || response.statusCode == 403 {
            apiKeyProvider.clearCredential()
        }

        return response
    }
}
