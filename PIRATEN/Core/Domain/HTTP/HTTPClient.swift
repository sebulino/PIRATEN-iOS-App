//
//  HTTPClient.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

/// HTTP methods supported by the client
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

/// A type-safe HTTP request definition
struct HTTPRequest {
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?

    init(
        url: URL,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }

    /// Creates a GET request
    static func get(_ url: URL, headers: [String: String] = [:]) -> HTTPRequest {
        HTTPRequest(url: url, method: .get, headers: headers)
    }

    /// Creates a POST request with JSON body
    static func post(_ url: URL, body: Data, headers: [String: String] = [:]) -> HTTPRequest {
        var allHeaders = headers
        allHeaders["Content-Type"] = "application/json"
        return HTTPRequest(url: url, method: .post, headers: allHeaders, body: body)
    }
}

/// Raw HTTP response before decoding
struct HTTPResponse {
    let data: Data
    let statusCode: Int
    let headers: [AnyHashable: Any]

    var isSuccess: Bool {
        (200...299).contains(statusCode)
    }
}

/// Protocol defining the HTTP client interface.
/// This abstraction allows swapping implementations (real URLSession vs mock) without changing consumers.
protocol HTTPClient: Sendable {
    /// Executes an HTTP request and returns the raw response.
    /// - Parameter request: The request to execute
    /// - Returns: The HTTP response containing data and status code
    /// - Throws: HTTPError if the request fails
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse

    /// Executes an HTTP request and decodes the response as JSON.
    /// - Parameters:
    ///   - request: The request to execute
    ///   - type: The type to decode the response into
    /// - Returns: The decoded response
    /// - Throws: HTTPError if the request fails or decoding fails
    func execute<T: Decodable & Sendable>(_ request: HTTPRequest, decoding type: T.Type) async throws -> T
}

/// Default implementation of JSON decoding for any HTTPClient
extension HTTPClient {
    func execute<T: Decodable & Sendable>(_ request: HTTPRequest, decoding type: T.Type) async throws -> T {
        let response = try await execute(request)

        guard response.isSuccess else {
            throw mapStatusCodeToError(response.statusCode, data: response.data)
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: response.data)
        } catch {
            throw HTTPError.decodingError(error.localizedDescription)
        }
    }

    private func mapStatusCodeToError(_ statusCode: Int, data: Data) -> HTTPError {
        let message = String(data: data, encoding: .utf8)

        switch statusCode {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        default:
            return .serverError(statusCode: statusCode, message: message)
        }
    }
}
