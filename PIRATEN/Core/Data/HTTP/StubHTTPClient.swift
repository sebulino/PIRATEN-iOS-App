//
//  StubHTTPClient.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

/// A stub HTTP client for testing and development.
/// Returns configurable responses without making network requests.
///
/// Example usage:
/// ```swift
/// let stubClient = StubHTTPClient(
///     responses: [
///         URL(string: "https://api.example.com/user")!: .success(userJSON),
///         URL(string: "https://api.example.com/forbidden")!: .failure(.forbidden)
///     ]
/// )
/// ```
final class StubHTTPClient: HTTPClient, @unchecked Sendable {

    enum StubResult {
        case success(Data, statusCode: Int = 200)
        case failure(HTTPError)
    }

    private var responses: [URL: StubResult]
    private var defaultResponse: StubResult

    /// Creates a stub client with predefined responses.
    /// - Parameters:
    ///   - responses: Dictionary mapping URLs to their stub responses
    ///   - defaultResponse: Response for URLs not in the dictionary (defaults to 404)
    init(
        responses: [URL: StubResult] = [:],
        defaultResponse: StubResult = .failure(.notFound)
    ) {
        self.responses = responses
        self.defaultResponse = defaultResponse
    }

    /// Sets a stub response for a specific URL
    func setResponse(_ result: StubResult, for url: URL) {
        responses[url] = result
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        let result = responses[request.url] ?? defaultResponse

        switch result {
        case .success(let data, let statusCode):
            return HTTPResponse(
                data: data,
                statusCode: statusCode,
                headers: [:]
            )
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Example Stub Responses

extension StubHTTPClient {
    /// Example: Creates a stub client that simulates a successful user info response
    static func withUserInfoStub() -> StubHTTPClient {
        let userJSON = """
        {
            "id": "12345",
            "username": "pirat",
            "displayName": "Piraten Mitglied",
            "email": "pirat@example.de"
        }
        """.data(using: .utf8)!

        return StubHTTPClient(responses: [
            URL(string: "https://api.example.com/userinfo")!: .success(userJSON)
        ])
    }

    /// Example: Creates a stub client that simulates 401 Unauthorized
    static func withUnauthorizedStub() -> StubHTTPClient {
        StubHTTPClient(defaultResponse: .failure(.unauthorized))
    }
}

// MARK: - Example Usage Documentation

/*
 ## Example: Using AuthenticatedHTTPClient with Stub

 This example shows how to use the HTTP client pattern for testing:

 ```swift
 // 1. Create a stub client
 let stubClient = StubHTTPClient.withUserInfoStub()

 // 2. Create a mock token provider
 struct MockTokenProvider: TokenProvider {
     func getValidAccessToken() async throws -> String {
         return "test-token-12345"
     }
 }

 // 3. Create the authenticated client
 let authenticatedClient = AuthenticatedHTTPClient(
     baseClient: stubClient,
     tokenProvider: MockTokenProvider(),
     onAuthError: { print("Auth error occurred") }
 )

 // 4. Make a request
 let request = HTTPRequest.get(URL(string: "https://api.example.com/userinfo")!)
 let response = try await authenticatedClient.execute(request)
 print("Status: \(response.statusCode)")
 ```

 ## Example: Real Usage with AuthStateManager

 ```swift
 // In AppContainer or similar composition root:
 let urlSessionClient = URLSessionHTTPClient()
 let tokenProvider = AuthStateTokenProvider(authStateManager: authStateManager)

 let apiClient = AuthenticatedHTTPClient(
     baseClient: urlSessionClient,
     tokenProvider: tokenProvider,
     onAuthError: { [weak authStateManager] in
         await authStateManager?.handleAuthenticationError()
     }
 )

 // Use apiClient for all authenticated API calls
 ```
 */
