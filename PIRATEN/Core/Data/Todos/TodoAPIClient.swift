//
//  TodoAPIClient.swift
//  PIRATEN
//
//  Created by Claude Code on 10.02.26.
//

import Foundation

/// API client for meine-piraten.de REST endpoints.
/// Follows the same pattern as DiscourseAPIClient: injected HTTPClient + baseURL,
/// methods return raw Data, error mapping to TodoAPIError.
@MainActor
final class TodoAPIClient {

    // MARK: - Properties

    private let httpClient: HTTPClient
    private let baseURL: URL

    // MARK: - Initialization

    init(httpClient: HTTPClient, baseURL: URL) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    // MARK: - Request Helpers

    private func url(for path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }

    private func commonHeaders() -> [String: String] {
        ["Accept": "application/json"]
    }

    // MARK: - Tasks

    /// GET /tasks.json
    func fetchTasks() async throws -> Data {
        let request = HTTPRequest.get(url(for: "/tasks.json"), headers: commonHeaders())
        return try await execute(request)
    }

    /// GET /tasks/:id.json
    func fetchTask(id: Int) async throws -> Data {
        let request = HTTPRequest.get(url(for: "/tasks/\(id).json"), headers: commonHeaders())
        return try await execute(request)
    }

    /// POST /tasks.json
    func createTask(params: [String: Any]) async throws -> Data {
        let body = try encodeParams(["task": params])
        let request = makePostRequest(path: "/tasks.json", body: body)
        return try await execute(request)
    }

    /// PATCH /tasks/:id.json
    func updateTask(id: Int, params: [String: Any]) async throws -> Data {
        let body = try encodeParams(["task": params])
        let request = makePatchRequest(path: "/tasks/\(id).json", body: body)
        return try await execute(request)
    }

    /// DELETE /tasks/:id.json
    func deleteTask(id: Int) async throws {
        let request = makeDeleteRequest(path: "/tasks/\(id).json")
        let response = try await executeRaw(request)
        guard response.isSuccess else {
            throw mapToError(statusCode: response.statusCode, data: response.data)
        }
    }

    // MARK: - Entities

    /// GET /entities.json
    func fetchEntities() async throws -> Data {
        let request = HTTPRequest.get(url(for: "/entities.json"), headers: commonHeaders())
        return try await execute(request)
    }

    // MARK: - Categories

    /// GET /categories.json
    func fetchCategories() async throws -> Data {
        let request = HTTPRequest.get(url(for: "/categories.json"), headers: commonHeaders())
        return try await execute(request)
    }

    // MARK: - Comments

    /// GET /tasks/:task_id/comments.json
    func fetchComments(taskId: Int) async throws -> Data {
        let request = HTTPRequest.get(url(for: "/tasks/\(taskId)/comments.json"), headers: commonHeaders())
        return try await execute(request)
    }

    /// POST /tasks/:task_id/comments.json
    func createComment(taskId: Int, params: [String: Any]) async throws -> Data {
        let body = try encodeParams(["comment": params])
        let request = makePostRequest(path: "/tasks/\(taskId)/comments.json", body: body)
        return try await execute(request)
    }

    /// DELETE /tasks/:task_id/comments/:id.json
    func deleteComment(taskId: Int, commentId: Int) async throws {
        let request = makeDeleteRequest(path: "/tasks/\(taskId)/comments/\(commentId).json")
        let response = try await executeRaw(request)
        guard response.isSuccess else {
            throw mapToError(statusCode: response.statusCode, data: response.data)
        }
    }

    // MARK: - Admin Requests

    /// GET /admin_requests/status.json
    func fetchAdminStatus() async throws -> Data {
        let request = HTTPRequest.get(url(for: "/admin_requests/status.json"), headers: commonHeaders())
        return try await execute(request)
    }

    /// POST /admin_requests.json
    func requestAdmin(reason: String) async throws -> Data {
        let body = try encodeParams(["reason": reason])
        let request = makePostRequest(path: "/admin_requests.json", body: body)
        return try await execute(request)
    }

    // MARK: - Private Helpers

    private func execute(_ request: HTTPRequest) async throws -> Data {
        do {
            let response = try await httpClient.execute(request)
            guard response.isSuccess else {
                throw mapToError(statusCode: response.statusCode, data: response.data)
            }
            return response.data
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        }
    }

    private func executeRaw(_ request: HTTPRequest) async throws -> HTTPResponse {
        do {
            return try await httpClient.execute(request)
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        }
    }

    private func encodeParams(_ params: [String: Any]) throws -> Data {
        do {
            return try JSONSerialization.data(withJSONObject: params)
        } catch {
            throw TodoAPIError.unknown(statusCode: nil, message: "Failed to encode request")
        }
    }

    private func makePostRequest(path: String, body: Data) -> HTTPRequest {
        var headers = commonHeaders()
        headers["Content-Type"] = "application/json"
        return HTTPRequest(url: url(for: path), method: .post, headers: headers, body: body)
    }

    private func makePatchRequest(path: String, body: Data) -> HTTPRequest {
        var headers = commonHeaders()
        headers["Content-Type"] = "application/json"
        return HTTPRequest(url: url(for: path), method: .patch, headers: headers, body: body)
    }

    private func makeDeleteRequest(path: String) -> HTTPRequest {
        HTTPRequest(url: url(for: path), method: .delete, headers: commonHeaders())
    }

    // MARK: - Error Mapping

    private func mapToError(statusCode: Int, data: Data) -> TodoAPIError {
        let message = String(data: data, encoding: .utf8)

        switch statusCode {
        case 404:
            return .notFound
        case 422:
            return .validationFailed(message: message)
        case 500...599:
            return .serverError(message: message)
        default:
            return .unknown(statusCode: statusCode, message: message)
        }
    }

    private func mapHTTPError(_ error: HTTPError) -> TodoAPIError {
        switch error {
        case .notFound:
            return .notFound
        case .networkError(let message):
            return .networkError(message: message)
        case .decodingError(let message):
            return .decodingError(message: message)
        case .cancelled:
            return .cancelled
        case .serverError(_, let message):
            return .serverError(message: message)
        case .unauthorized, .forbidden:
            return .unknown(statusCode: nil, message: error.localizedDescription)
        case .unknown(let message):
            return .unknown(statusCode: nil, message: message)
        }
    }
}
