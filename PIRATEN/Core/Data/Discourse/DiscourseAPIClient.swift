//
//  DiscourseAPIClient.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

/// Discourse API client for authenticated requests.
/// Uses AuthenticatedHTTPClient to inject Bearer tokens into all requests.
///
/// ## Authentication Strategy (Q-002)
/// The authentication method depends on how Discourse is configured:
/// - **Bearer passthrough**: If Discourse trusts the same Keycloak realm, the SSO access token
///   is passed directly via `Authorization: Bearer <token>` header
/// - **User API Key**: If Discourse uses its own auth, a `User-Api-Key` header would be needed
///
/// Current implementation assumes Bearer passthrough (Option A from Q-002).
/// See: Docs/OPEN_QUESTIONS.md Q-002 for details.
///
/// ## Rate Limiting
/// Discourse defaults: 20 requests/minute, 2,880 requests/day for authenticated users.
/// No retry logic implemented yet - see Q-006.
///
/// ## Base URL
/// Uses https://diskussion.piratenpartei.de as documented in prd.json.
@MainActor
final class DiscourseAPIClient {

    // MARK: - Properties

    /// The underlying authenticated HTTP client that handles token injection
    private let httpClient: HTTPClient

    /// Base URL for all Discourse API requests
    private let baseURL: URL

    // MARK: - Initialization

    /// Creates a Discourse API client.
    /// - Parameters:
    ///   - httpClient: An authenticated HTTP client (should be AuthenticatedHTTPClient)
    ///   - baseURL: Base URL of the Discourse instance (e.g., https://diskussion.piratenpartei.de)
    init(httpClient: HTTPClient, baseURL: URL) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    // MARK: - Request Helpers

    /// Builds a URL for the given API path.
    /// - Parameter path: API path (e.g., "/latest.json", "/t/123.json")
    /// - Returns: Full URL for the request
    private func url(for path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }

    /// Creates common headers for Discourse API requests.
    /// - Returns: Headers dictionary with Accept header set
    private func commonHeaders() -> [String: String] {
        // Note: Authorization header is added by AuthenticatedHTTPClient
        [
            "Accept": "application/json"
        ]
    }

    // MARK: - API Methods

    /// Fetches the latest topics from the forum.
    /// Endpoint: GET /latest.json
    /// - Returns: Raw response data for decoding by the caller
    /// - Throws: DiscourseError if the request fails
    func fetchLatest() async throws -> Data {
        let request = HTTPRequest.get(url(for: "/latest.json"), headers: commonHeaders())
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
            }
            return response.data
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
    }

    /// Fetches a single topic with its posts.
    /// Endpoint: GET /t/{topic_id}.json
    /// - Parameter topicId: The ID of the topic to fetch
    /// - Returns: Raw response data for decoding by the caller
    /// - Throws: DiscourseError if the request fails
    func fetchTopic(id topicId: Int) async throws -> Data {
        let request = HTTPRequest.get(url(for: "/t/\(topicId).json"), headers: commonHeaders())
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
            }
            return response.data
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
    }

    /// Fetches private messages for the current user.
    /// Endpoint: GET /topics/private-messages/{username}.json
    /// - Parameter username: The username whose private messages to fetch
    /// - Returns: Raw response data for decoding by the caller
    /// - Throws: DiscourseError if the request fails
    func fetchPrivateMessages(for username: String) async throws -> Data {
        let path = "/topics/private-messages/\(username).json"
        let request = HTTPRequest.get(url(for: path), headers: commonHeaders())
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
            }
            return response.data
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
    }

    /// Fetches a specific private message thread.
    /// Endpoint: GET /t/{topic_id}.json (PMs are topics with archetype 'private_message')
    /// - Parameter topicId: The ID of the PM thread (which is a topic)
    /// - Returns: Raw response data for decoding by the caller
    /// - Throws: DiscourseError if the request fails
    func fetchPrivateMessageThread(id topicId: Int) async throws -> Data {
        // PMs in Discourse are just topics with archetype='private_message'
        // The same endpoint works for both
        try await fetchTopic(id: topicId)
    }

    /// Posts a reply to an existing message thread (PM).
    /// Endpoint: POST /posts.json
    /// - Parameters:
    ///   - topicId: The ID of the PM thread to reply to
    ///   - content: The raw markdown content of the reply
    /// - Returns: Raw response data containing the created post
    /// - Throws: DiscourseError if the request fails
    ///
    /// Note: This uses the standard Discourse post creation endpoint.
    /// For PMs, topic_id is sufficient - no category is needed.
    func replyToMessageThread(topicId: Int, content: String) async throws -> Data {
        let body = CreatePostRequest(topicId: topicId, raw: content)
        let bodyData: Data
        do {
            bodyData = try JSONEncoder().encode(body)
        } catch {
            throw DiscourseError.unknown(statusCode: nil, message: "Failed to encode request")
        }

        var headers = commonHeaders()
        headers["Content-Type"] = "application/json"

        let request = HTTPRequest.post(url(for: "/posts.json"), body: bodyData, headers: headers)
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToDiscourseError(statusCode: response.statusCode, data: response.data)
            }
            return response.data
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch let error as DiscourseAuthError {
            throw mapDiscourseAuthError(error)
        }
    }

    // MARK: - Error Mapping

    /// Maps HTTP status codes to Discourse-specific errors.
    private func mapToDiscourseError(statusCode: Int, data: Data) -> DiscourseError {
        // Try to parse Discourse error response
        let message = parseErrorMessage(from: data)

        switch statusCode {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 429:
            return .rateLimited
        case 500...599:
            return .serverError(message: message)
        default:
            return .unknown(statusCode: statusCode, message: message)
        }
    }

    /// Maps DiscourseAuthError to DiscourseError.
    private func mapDiscourseAuthError(_ error: DiscourseAuthError) -> DiscourseError {
        switch error {
        case .notAuthenticated:
            return .unauthorized
        default:
            return .unauthorized
        }
    }

    /// Maps HTTPError to DiscourseError.
    private func mapHTTPError(_ error: HTTPError) -> DiscourseError {
        switch error {
        case .unauthorized:
            return .unauthorized
        case .forbidden:
            return .forbidden
        case .notFound:
            return .notFound
        case .networkError(let message):
            return .networkError(message: message)
        case .decodingError(let message):
            return .decodingError(message: message)
        case .cancelled:
            return .cancelled
        case .serverError(let statusCode, let message):
            if statusCode == 429 {
                return .rateLimited
            }
            return .serverError(message: message)
        case .unknown(let message):
            return .unknown(statusCode: nil, message: message)
        }
    }

    /// Attempts to parse an error message from Discourse JSON error response.
    /// Discourse typically returns: { "errors": ["message1", "message2"], "error_type": "..." }
    private func parseErrorMessage(from data: Data) -> String? {
        struct DiscourseErrorResponse: Decodable {
            let errors: [String]?
            let errorType: String?
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        if let errorResponse = try? decoder.decode(DiscourseErrorResponse.self, from: data) {
            return errorResponse.errors?.joined(separator: ", ")
        }
        return nil
    }
}

// MARK: - Request DTOs

/// Request body for creating a post (reply) via POST /posts.json
private struct CreatePostRequest: Encodable {
    let topicId: Int
    let raw: String

    enum CodingKeys: String, CodingKey {
        case topicId = "topic_id"
        case raw
    }
}
