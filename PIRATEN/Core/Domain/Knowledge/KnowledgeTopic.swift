//
//  KnowledgeTopic.swift
//  PIRATEN
//

import Foundation

/// Metadata for a single knowledge topic (lesson).
/// Maps to a `.md` file in the PIRATEN-Kanon repo.
/// The full content body is loaded separately via `TopicContent`.
struct KnowledgeTopic: Identifiable, Equatable, Codable {
    /// Unique identifier (from frontmatter `id` field, e.g., "bundestagswahl")
    let id: String

    /// Display title
    let title: String

    /// Short summary shown in lists
    let summary: String

    /// ID of the parent category
    let categoryId: String

    /// Searchable tags (e.g., ["Bundestag", "Wahlrecht"])
    let tags: [String]

    /// Difficulty level (e.g., "Einsteiger", "Fortgeschritten")
    let level: String

    /// Estimated reading time in minutes
    let readingMinutes: Int

    /// Content version string (e.g., "1.0")
    let version: String?

    /// Date the content was last updated
    let lastUpdated: Date?

    /// Optional quiz questions embedded in frontmatter
    let quiz: [QuizQuestion]?

    /// IDs of related topics for cross-linking
    let relatedTopicIds: [String]?

    /// Path to the `.md` file in the repo (e.g., "kommunalpolitik/kommunalpolitik-grundlagen.md")
    let contentPath: String
}
