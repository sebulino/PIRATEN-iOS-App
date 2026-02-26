//
//  NewsAPIClient.swift
//  PIRATEN
//

import Foundation

/// HTTP client for the meine-piraten.de news API.
/// Fetches aggregated news items from the Rails backend.
final class NewsAPIClient: Sendable {

    // MARK: - Dependencies

    private let httpClient: HTTPClient
    private let baseURL: URL

    // MARK: - Initialization

    init(httpClient: HTTPClient, baseURL: URL) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    // MARK: - Public Methods

    /// Fetches news items from the backend.
    /// - Parameter limit: Maximum number of items to return (default 50).
    /// - Returns: Array of `NewsItem` sorted newest-first by the backend.
    func fetchNews(limit: Int = 50) async throws -> [NewsItem] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/news"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components?.url else {
            throw NewsAPIError.invalidURL
        }

        let request = HTTPRequest.get(url)
        let response = try await httpClient.execute(request)

        guard response.isSuccess else {
            throw NewsAPIError.serverError(statusCode: response.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds first
            let formatterWithFraction = ISO8601DateFormatter()
            formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatterWithFraction.date(from: dateString) {
                return date
            }

            // Fall back to standard ISO8601
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateString)")
        }

        do {
            return try decoder.decode([NewsItem].self, from: response.data)
        } catch {
            throw NewsAPIError.decodingError(error.localizedDescription)
        }
    }
}

// MARK: - Errors

enum NewsAPIError: Error, LocalizedError {
    case invalidURL
    case serverError(statusCode: Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ungültige News API URL"
        case .serverError(let statusCode):
            return "News API Fehler (Status: \(statusCode))"
        case .decodingError(let message):
            return "Fehler beim Verarbeiten der News-Daten: \(message)"
        }
    }
}
