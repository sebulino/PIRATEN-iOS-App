//
//  KnowledgeRepository.swift
//  PIRATEN
//

import Foundation

/// Errors that can occur when fetching knowledge content.
enum KnowledgeError: Error, Equatable {
    /// Network request failed
    case networkError(String)

    /// Content could not be parsed (malformed YAML/markdown)
    case parsingError(String)

    /// Requested topic or category not found
    case notFound

    /// GitHub API rate limit exceeded
    case rateLimited

    var localizedDescription: String {
        switch self {
        case .networkError(let message):
            return "Netzwerkfehler: \(message)"
        case .parsingError(let message):
            return "Inhalt konnte nicht gelesen werden: \(message)"
        case .notFound:
            return "Inhalt nicht gefunden"
        case .rateLimited:
            return "Zu viele Anfragen — bitte später erneut versuchen"
        }
    }
}

/// Repository for fetching and caching knowledge content from the PIRATEN-Kanon repo.
@MainActor
protocol KnowledgeRepository {
    /// Fetches the full content index (categories + topic metadata).
    /// Uses cached data when available and fresh; refreshes from GitHub otherwise.
    /// - Parameter forceRefresh: If true, bypasses cache TTL and fetches from GitHub
    /// - Returns: The knowledge index
    func fetchIndex(forceRefresh: Bool) async throws -> KnowledgeIndex

    /// Fetches the full content of a specific topic (markdown parsed into sections).
    /// Uses cached content when available.
    /// - Parameter topicId: The topic to fetch content for
    /// - Returns: Parsed topic content with structured sections
    func fetchTopicContent(topicId: String) async throws -> TopicContent
}
