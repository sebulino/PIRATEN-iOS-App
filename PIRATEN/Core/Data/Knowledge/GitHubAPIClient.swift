//
//  GitHubAPIClient.swift
//  PIRATEN
//

import Foundation

/// Result of a directory contents fetch that supports ETag conditional requests.
enum GitHubDirectoryResult {
    /// Content was modified since last ETag; includes new items and updated ETag
    case modified(items: [GitHubContentItem], etag: String?)
    /// Content has not changed (HTTP 304)
    case notModified
}

/// Represents a single item from the GitHub Contents API directory listing.
struct GitHubContentItem: Decodable {
    let name: String
    let path: String
    let type: String
    let downloadUrl: String?

    enum CodingKeys: String, CodingKey {
        case name, path, type
        case downloadUrl = "download_url"
    }
}

/// API client for fetching content from a public GitHub repository.
/// Uses the GitHub Contents API with conditional ETag requests to minimize
/// bandwidth and rate limit consumption.
///
/// Follows the same pattern as DiscourseAPIClient: injected HTTPClient,
/// methods return raw Data or typed results, error mapping to KnowledgeError.
final class GitHubAPIClient: Sendable {

    // MARK: - Properties

    private let httpClient: HTTPClient
    private let repoOwner: String
    private let repoName: String
    private let branch: String

    // MARK: - Initialization

    init(httpClient: HTTPClient, repoOwner: String, repoName: String, branch: String) {
        self.httpClient = httpClient
        self.repoOwner = repoOwner
        self.repoName = repoName
        self.branch = branch
    }

    // MARK: - API Methods

    /// Fetches directory contents from the GitHub Contents API.
    /// Supports conditional requests via ETag to avoid re-downloading unchanged content.
    ///
    /// - Parameters:
    ///   - path: Path within the repository (e.g., "Grundlagen")
    ///   - etag: Previous ETag value for conditional request; nil for first fetch
    /// - Returns: `.modified` with items and new ETag, or `.notModified` if unchanged
    /// - Throws: `KnowledgeError` on failure
    func fetchDirectoryContents(path: String, etag: String? = nil) async throws -> GitHubDirectoryResult {
        let url = contentsURL(for: path)
        var headers = commonHeaders()
        if let etag {
            headers["If-None-Match"] = etag
        }

        let request = HTTPRequest.get(url, headers: headers)

        do {
            let response = try await httpClient.execute(request)

            if response.statusCode == 304 {
                return .notModified
            }

            guard response.isSuccess else {
                throw mapToKnowledgeError(statusCode: response.statusCode, headers: response.headers)
            }

            let decoder = JSONDecoder()
            let items = try decoder.decode([GitHubContentItem].self, from: response.data)
            let newEtag = response.headers["Etag"] as? String
                ?? response.headers["etag"] as? String

            return .modified(items: items, etag: newEtag)
        } catch let error as KnowledgeError {
            throw error
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch {
            throw KnowledgeError.parsingError("Failed to decode directory contents: \(error.localizedDescription)")
        }
    }

    /// Fetches raw file content via a download URL.
    ///
    /// - Parameter downloadURL: The `download_url` from a `GitHubContentItem`
    /// - Returns: Raw file content as Data
    /// - Throws: `KnowledgeError` on failure
    func fetchRawFile(downloadURL: String) async throws -> Data {
        guard let url = URL(string: downloadURL) else {
            throw KnowledgeError.parsingError("Invalid download URL: \(downloadURL)")
        }

        let request = HTTPRequest.get(url)

        do {
            let response = try await httpClient.execute(request)

            guard response.isSuccess else {
                throw mapToKnowledgeError(statusCode: response.statusCode, headers: response.headers)
            }

            return response.data
        } catch let error as KnowledgeError {
            throw error
        } catch let error as HTTPError {
            throw mapHTTPError(error)
        } catch {
            throw KnowledgeError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    private func contentsURL(for path: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        components.path = "/repos/\(repoOwner)/\(repoName)/contents/\(path)"
        components.queryItems = [URLQueryItem(name: "ref", value: branch)]
        return components.url!
    }

    private func commonHeaders() -> [String: String] {
        ["Accept": "application/vnd.github+json"]
    }

    private func mapToKnowledgeError(statusCode: Int, headers: [AnyHashable: Any]) -> KnowledgeError {
        switch statusCode {
        case 403:
            let remaining = headers["X-RateLimit-Remaining"] as? String
                ?? headers["x-ratelimit-remaining"] as? String
            if remaining == "0" {
                return .rateLimited
            }
            return .networkError("Forbidden (HTTP 403)")
        case 404:
            return .notFound
        case 500...599:
            return .networkError("Server error (HTTP \(statusCode))")
        default:
            return .networkError("Unexpected HTTP status \(statusCode)")
        }
    }

    private func mapHTTPError(_ error: HTTPError) -> KnowledgeError {
        switch error {
        case .networkError(let message):
            return .networkError(message)
        case .notFound:
            return .notFound
        case .cancelled:
            return .networkError("Request cancelled")
        default:
            return .networkError(error.localizedDescription)
        }
    }
}
