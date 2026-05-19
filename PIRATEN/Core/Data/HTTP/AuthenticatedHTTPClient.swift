//
//  AuthenticatedHTTPClient.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

/// Protocol for providing access tokens on demand.
/// This decouples the HTTP client from specific auth implementations.
protocol TokenProvider: Sendable {
    /// Retrieves a valid access token, refreshing if necessary.
    /// - Returns: A valid access token
    /// - Throws: Error if token cannot be obtained (e.g., user not authenticated)
    func getValidAccessToken() async throws -> String
}

/// Callback for handling authentication errors (401/403).
/// Called when the server rejects the token.
typealias AuthErrorHandler = @Sendable () async -> Void

/// An HTTP client that attaches Bearer tokens to requests.
/// Wraps an underlying HTTPClient and handles token injection.
///
/// Usage:
/// ```swift
/// let client = AuthenticatedHTTPClient(
///     baseClient: URLSessionHTTPClient(),
///     tokenProvider: authStateManager,
///     onAuthError: { await authStateManager.handleAuthenticationError() }
/// )
/// let response = try await client.execute(.get(someURL))
/// ```
final class AuthenticatedHTTPClient: HTTPClient, @unchecked Sendable {
    private let baseClient: HTTPClient
    private let tokenProvider: TokenProvider
    private let onAuthError: AuthErrorHandler?

    /// Creates an authenticated HTTP client.
    /// - Parameters:
    ///   - baseClient: The underlying HTTP client for actual network requests
    ///   - tokenProvider: Provider for valid access tokens
    ///   - onAuthError: Optional callback for 401/403 responses to trigger re-auth flow
    init(
        baseClient: HTTPClient,
        tokenProvider: TokenProvider,
        onAuthError: AuthErrorHandler? = nil
    ) {
        self.baseClient = baseClient
        self.tokenProvider = tokenProvider
        self.onAuthError = onAuthError
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        // Get a valid access token
        let token: String
        do {
            token = try await tokenProvider.getValidAccessToken()
        } catch {
            // Cannot get token - user is not authenticated
            throw HTTPError.unauthorized
        }

        // Add Authorization header to the request
        var authenticatedRequest = request
        var headers = request.headers
        headers["Authorization"] = "Bearer \(token)"
        authenticatedRequest = HTTPRequest(
            url: request.url,
            method: request.method,
            headers: headers,
            body: request.body
        )

        // Execute the request
        let response: HTTPResponse
        do {
            response = try await baseClient.execute(authenticatedRequest)
        } catch {
            throw error
        }

        // Check for auth errors. Per the meine-piraten.de API contract:
        //   401 — missing/invalid/expired token → session is gone
        //   403 — valid token, insufficient permissions → user lacks rights
        //         for THIS request, but their session is fine
        //
        // Only 401 triggers the central session-expiry handler. A 403
        // throws .forbidden so the caller can surface it as a "you don't
        // have permission" error without wiping the user's session.
        if response.statusCode == 401 {
            await onAuthError?()
            throw HTTPError.unauthorized
        }
        if response.statusCode == 403 {
            throw HTTPError.forbidden
        }

        return response
    }
}
