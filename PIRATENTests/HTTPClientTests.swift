//
//  HTTPClientTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 31.01.26.
//

import Foundation
import Testing
@testable import PIRATEN

// MARK: - HTTPRequest Tests

struct HTTPRequestTests {

    @Test func initializesWithDefaults() {
        let url = URL(string: "https://api.example.com/test")!
        let request = HTTPRequest(url: url)

        #expect(request.url == url)
        #expect(request.method == .get)
        #expect(request.headers.isEmpty)
        #expect(request.body == nil)
    }

    @Test func initializesWithAllParameters() {
        let url = URL(string: "https://api.example.com/test")!
        let headers = ["Accept": "application/json"]
        let body = "test body".data(using: .utf8)

        let request = HTTPRequest(
            url: url,
            method: .post,
            headers: headers,
            body: body
        )

        #expect(request.url == url)
        #expect(request.method == .post)
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.body == body)
    }

    @Test func getFactoryMethod() {
        let url = URL(string: "https://api.example.com/get")!
        let headers = ["Custom": "Header"]

        let request = HTTPRequest.get(url, headers: headers)

        #expect(request.url == url)
        #expect(request.method == .get)
        #expect(request.headers["Custom"] == "Header")
        #expect(request.body == nil)
    }

    @Test func postFactoryMethodAddsContentType() {
        let url = URL(string: "https://api.example.com/post")!
        let body = """
        {"key": "value"}
        """.data(using: .utf8)!

        let request = HTTPRequest.post(url, body: body)

        #expect(request.url == url)
        #expect(request.method == .post)
        #expect(request.headers["Content-Type"] == "application/json")
        #expect(request.body == body)
    }

    @Test func postFactoryMethodPreservesExistingHeaders() {
        let url = URL(string: "https://api.example.com/post")!
        let body = "{}".data(using: .utf8)!
        let headers = ["Accept": "application/json"]

        let request = HTTPRequest.post(url, body: body, headers: headers)

        #expect(request.headers["Accept"] == "application/json")
        #expect(request.headers["Content-Type"] == "application/json")
    }
}

// MARK: - HTTPResponse Tests

struct HTTPResponseTests {

    @Test func isSuccessForStatusCode200() {
        let response = HTTPResponse(data: Data(), statusCode: 200, headers: [:])
        #expect(response.isSuccess == true)
    }

    @Test func isSuccessForStatusCode201() {
        let response = HTTPResponse(data: Data(), statusCode: 201, headers: [:])
        #expect(response.isSuccess == true)
    }

    @Test func isSuccessForStatusCode204() {
        let response = HTTPResponse(data: Data(), statusCode: 204, headers: [:])
        #expect(response.isSuccess == true)
    }

    @Test func isNotSuccessForStatusCode400() {
        let response = HTTPResponse(data: Data(), statusCode: 400, headers: [:])
        #expect(response.isSuccess == false)
    }

    @Test func isNotSuccessForStatusCode401() {
        let response = HTTPResponse(data: Data(), statusCode: 401, headers: [:])
        #expect(response.isSuccess == false)
    }

    @Test func isNotSuccessForStatusCode500() {
        let response = HTTPResponse(data: Data(), statusCode: 500, headers: [:])
        #expect(response.isSuccess == false)
    }
}

// MARK: - HTTPError Tests

struct HTTPErrorTests {

    @Test func isAuthenticationErrorForUnauthorized() {
        let error = HTTPError.unauthorized
        #expect(error.isAuthenticationError == true)
    }

    @Test func isAuthenticationErrorForForbidden() {
        let error = HTTPError.forbidden
        #expect(error.isAuthenticationError == true)
    }

    @Test func isNotAuthenticationErrorForNotFound() {
        let error = HTTPError.notFound
        #expect(error.isAuthenticationError == false)
    }

    @Test func isNotAuthenticationErrorForNetworkError() {
        let error = HTTPError.networkError("Connection failed")
        #expect(error.isAuthenticationError == false)
    }

    @Test func isNotAuthenticationErrorForServerError() {
        let error = HTTPError.serverError(statusCode: 500, message: nil)
        #expect(error.isAuthenticationError == false)
    }

    @Test func localizedDescriptionForUnauthorized() {
        let error = HTTPError.unauthorized
        #expect(error.localizedDescription.contains("autorisiert"))
    }

    @Test func localizedDescriptionForForbidden() {
        let error = HTTPError.forbidden
        #expect(error.localizedDescription.contains("verweigert"))
    }

    @Test func localizedDescriptionForNotFound() {
        let error = HTTPError.notFound
        #expect(error.localizedDescription.contains("nicht gefunden"))
    }

    @Test func errorsAreEquatable() {
        #expect(HTTPError.unauthorized == HTTPError.unauthorized)
        #expect(HTTPError.forbidden == HTTPError.forbidden)
        #expect(HTTPError.notFound == HTTPError.notFound)
        #expect(HTTPError.unauthorized != HTTPError.forbidden)
    }
}

// MARK: - StubHTTPClient Tests

struct StubHTTPClientTests {

    @Test func returnsConfiguredSuccessResponse() async throws {
        let url = URL(string: "https://api.example.com/data")!
        let responseData = """
        {"status": "ok"}
        """.data(using: .utf8)!

        let client = StubHTTPClient(responses: [
            url: .success(responseData, statusCode: 200)
        ])

        let response = try await client.execute(.get(url))

        #expect(response.statusCode == 200)
        #expect(response.data == responseData)
    }

    @Test func returnsConfiguredErrorResponse() async throws {
        let url = URL(string: "https://api.example.com/forbidden")!

        let client = StubHTTPClient(responses: [
            url: .failure(.forbidden)
        ])

        do {
            _ = try await client.execute(.get(url))
            Issue.record("Expected HTTPError.forbidden to be thrown")
        } catch let error as HTTPError {
            #expect(error == .forbidden)
        }
    }

    @Test func returns404ForUnknownURLByDefault() async throws {
        let url = URL(string: "https://api.example.com/unknown")!
        let client = StubHTTPClient()

        do {
            _ = try await client.execute(.get(url))
            Issue.record("Expected HTTPError.notFound to be thrown")
        } catch let error as HTTPError {
            #expect(error == .notFound)
        }
    }

    @Test func customDefaultResponse() async throws {
        let url = URL(string: "https://api.example.com/any")!
        let client = StubHTTPClient(defaultResponse: .failure(.unauthorized))

        do {
            _ = try await client.execute(.get(url))
            Issue.record("Expected HTTPError.unauthorized to be thrown")
        } catch let error as HTTPError {
            #expect(error == .unauthorized)
        }
    }

    @Test func setResponseUpdatesStub() async throws {
        let url = URL(string: "https://api.example.com/dynamic")!
        let client = StubHTTPClient()

        // Initially returns 404
        do {
            _ = try await client.execute(.get(url))
            Issue.record("Expected 404")
        } catch let error as HTTPError {
            #expect(error == .notFound)
        }

        // Update the stub
        let newData = "updated".data(using: .utf8)!
        client.setResponse(.success(newData, statusCode: 200), for: url)

        // Now returns success
        let response = try await client.execute(.get(url))
        #expect(response.statusCode == 200)
        #expect(response.data == newData)
    }

    @Test func withUserInfoStubReturnsUserData() async throws {
        let client = StubHTTPClient.withUserInfoStub()
        let url = URL(string: "https://api.example.com/userinfo")!

        let response = try await client.execute(.get(url))

        #expect(response.statusCode == 200)

        // Verify the response contains expected user data
        let json = try JSONSerialization.jsonObject(with: response.data) as! [String: Any]
        #expect(json["id"] as? String == "12345")
        #expect(json["username"] as? String == "pirat")
    }

    @Test func withUnauthorizedStubReturnsUnauthorized() async throws {
        let client = StubHTTPClient.withUnauthorizedStub()
        let url = URL(string: "https://api.example.com/anything")!

        do {
            _ = try await client.execute(.get(url))
            Issue.record("Expected HTTPError.unauthorized to be thrown")
        } catch let error as HTTPError {
            #expect(error == .unauthorized)
        }
    }
}

// MARK: - AuthenticatedHTTPClient Tests

/// Mock token provider for testing
struct MockTokenProvider: TokenProvider {
    let token: String
    let shouldFail: Bool

    init(token: String = "test-token-123", shouldFail: Bool = false) {
        self.token = token
        self.shouldFail = shouldFail
    }

    func getValidAccessToken() async throws -> String {
        if shouldFail {
            throw TokenProviderError.notAuthenticated
        }
        return token
    }
}

struct AuthenticatedHTTPClientTests {

    @Test func addsAuthorizationHeader() async throws {
        let url = URL(string: "https://api.example.com/protected")!
        let responseData = "protected data".data(using: .utf8)!

        // Create a custom stub that captures the request
        let capturedClient = RequestCapturingStubClient(
            response: .success(responseData, statusCode: 200)
        )

        let tokenProvider = MockTokenProvider(token: "my-bearer-token")
        let client = AuthenticatedHTTPClient(
            baseClient: capturedClient,
            tokenProvider: tokenProvider
        )

        _ = try await client.execute(.get(url))

        // Verify Authorization header was added
        let authHeader = capturedClient.lastRequest?.headers["Authorization"]
        #expect(authHeader == "Bearer my-bearer-token")
    }

    @Test func throwsUnauthorizedWhenTokenProviderFails() async throws {
        let url = URL(string: "https://api.example.com/protected")!
        let stubClient = StubHTTPClient(defaultResponse: .success(Data(), statusCode: 200))
        let tokenProvider = MockTokenProvider(shouldFail: true)

        let client = AuthenticatedHTTPClient(
            baseClient: stubClient,
            tokenProvider: tokenProvider
        )

        do {
            _ = try await client.execute(.get(url))
            Issue.record("Expected HTTPError.unauthorized to be thrown")
        } catch let error as HTTPError {
            #expect(error == .unauthorized)
        }
    }

    @Test func callsAuthErrorHandlerOn401() async throws {
        let url = URL(string: "https://api.example.com/protected")!
        let stubClient = RequestCapturingStubClient(
            response: .success(Data(), statusCode: 401)
        )
        let tokenProvider = MockTokenProvider()

        var authErrorCalled = false
        let client = AuthenticatedHTTPClient(
            baseClient: stubClient,
            tokenProvider: tokenProvider,
            onAuthError: {
                authErrorCalled = true
            }
        )

        do {
            _ = try await client.execute(.get(url))
            Issue.record("Expected HTTPError.unauthorized to be thrown")
        } catch let error as HTTPError {
            #expect(error == .unauthorized)
        }

        #expect(authErrorCalled == true)
    }

    @Test func callsAuthErrorHandlerOn403() async throws {
        let url = URL(string: "https://api.example.com/protected")!
        let stubClient = RequestCapturingStubClient(
            response: .success(Data(), statusCode: 403)
        )
        let tokenProvider = MockTokenProvider()

        var authErrorCalled = false
        let client = AuthenticatedHTTPClient(
            baseClient: stubClient,
            tokenProvider: tokenProvider,
            onAuthError: {
                authErrorCalled = true
            }
        )

        do {
            _ = try await client.execute(.get(url))
            Issue.record("Expected HTTPError.forbidden to be thrown")
        } catch let error as HTTPError {
            #expect(error == .forbidden)
        }

        #expect(authErrorCalled == true)
    }

    @Test func doesNotCallAuthErrorHandlerOnSuccess() async throws {
        let url = URL(string: "https://api.example.com/protected")!
        let stubClient = RequestCapturingStubClient(
            response: .success("ok".data(using: .utf8)!, statusCode: 200)
        )
        let tokenProvider = MockTokenProvider()

        var authErrorCalled = false
        let client = AuthenticatedHTTPClient(
            baseClient: stubClient,
            tokenProvider: tokenProvider,
            onAuthError: {
                authErrorCalled = true
            }
        )

        _ = try await client.execute(.get(url))

        #expect(authErrorCalled == false)
    }

    @Test func preservesExistingHeaders() async throws {
        let url = URL(string: "https://api.example.com/protected")!
        let capturedClient = RequestCapturingStubClient(
            response: .success(Data(), statusCode: 200)
        )
        let tokenProvider = MockTokenProvider(token: "token123")

        let client = AuthenticatedHTTPClient(
            baseClient: capturedClient,
            tokenProvider: tokenProvider
        )

        let request = HTTPRequest(
            url: url,
            method: .post,
            headers: ["Content-Type": "application/json", "Accept": "application/json"],
            body: "{}".data(using: .utf8)
        )

        _ = try await client.execute(request)

        let headers = capturedClient.lastRequest?.headers
        #expect(headers?["Content-Type"] == "application/json")
        #expect(headers?["Accept"] == "application/json")
        #expect(headers?["Authorization"] == "Bearer token123")
    }
}

// MARK: - JSON Decoding Tests

struct HTTPClientJSONDecodingTests {

    struct TestModel: Decodable, Equatable {
        let id: Int
        let userName: String
        let createdAt: Date
    }

    @Test func decodesJSONWithSnakeCaseConversion() async throws {
        let url = URL(string: "https://api.example.com/model")!
        let json = """
        {
            "id": 42,
            "user_name": "test_user",
            "created_at": "2025-01-31T12:00:00Z"
        }
        """.data(using: .utf8)!

        let client = StubHTTPClient(responses: [
            url: .success(json, statusCode: 200)
        ])

        let result: TestModel = try await client.execute(.get(url), decoding: TestModel.self)

        #expect(result.id == 42)
        #expect(result.userName == "test_user")
    }

    @Test func throwsDecodingErrorForInvalidJSON() async throws {
        let url = URL(string: "https://api.example.com/model")!
        let invalidJson = "not valid json".data(using: .utf8)!

        let client = StubHTTPClient(responses: [
            url: .success(invalidJson, statusCode: 200)
        ])

        do {
            let _: TestModel = try await client.execute(.get(url), decoding: TestModel.self)
            Issue.record("Expected decoding error")
        } catch let error as HTTPError {
            switch error {
            case .decodingError:
                // Expected
                break
            default:
                Issue.record("Expected decodingError, got \(error)")
            }
        }
    }

    @Test func throwsUnauthorizedFor401StatusCode() async throws {
        let url = URL(string: "https://api.example.com/model")!
        let client = RequestCapturingStubClient(
            response: .success("Unauthorized".data(using: .utf8)!, statusCode: 401)
        )

        do {
            let _: TestModel = try await client.execute(.get(url), decoding: TestModel.self)
            Issue.record("Expected unauthorized error")
        } catch let error as HTTPError {
            #expect(error == .unauthorized)
        }
    }

    @Test func throwsForbiddenFor403StatusCode() async throws {
        let url = URL(string: "https://api.example.com/model")!
        let client = RequestCapturingStubClient(
            response: .success("Forbidden".data(using: .utf8)!, statusCode: 403)
        )

        do {
            let _: TestModel = try await client.execute(.get(url), decoding: TestModel.self)
            Issue.record("Expected forbidden error")
        } catch let error as HTTPError {
            #expect(error == .forbidden)
        }
    }

    @Test func throwsNotFoundFor404StatusCode() async throws {
        let url = URL(string: "https://api.example.com/model")!
        let client = RequestCapturingStubClient(
            response: .success("Not Found".data(using: .utf8)!, statusCode: 404)
        )

        do {
            let _: TestModel = try await client.execute(.get(url), decoding: TestModel.self)
            Issue.record("Expected notFound error")
        } catch let error as HTTPError {
            #expect(error == .notFound)
        }
    }

    @Test func throwsServerErrorFor500StatusCode() async throws {
        let url = URL(string: "https://api.example.com/model")!
        let errorMessage = "Internal Server Error"
        let client = RequestCapturingStubClient(
            response: .success(errorMessage.data(using: .utf8)!, statusCode: 500)
        )

        do {
            let _: TestModel = try await client.execute(.get(url), decoding: TestModel.self)
            Issue.record("Expected server error")
        } catch let error as HTTPError {
            switch error {
            case .serverError(let statusCode, let message):
                #expect(statusCode == 500)
                #expect(message == errorMessage)
            default:
                Issue.record("Expected serverError, got \(error)")
            }
        }
    }
}

// MARK: - Test Helpers

/// A stub HTTP client that captures the last request for inspection
final class RequestCapturingStubClient: HTTPClient, @unchecked Sendable {
    private(set) var lastRequest: HTTPRequest?
    private let response: StubHTTPClient.StubResult

    init(response: StubHTTPClient.StubResult) {
        self.response = response
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        lastRequest = request

        switch response {
        case .success(let data, let statusCode):
            return HTTPResponse(data: data, statusCode: statusCode, headers: [:])
        case .failure(let error):
            throw error
        }
    }
}
