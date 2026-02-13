//
//  KnowledgeIndex.swift
//  PIRATEN
//

import Foundation

/// A curated learning path grouping topics in a recommended order.
struct LearningPath: Codable, Equatable {
    /// Unique identifier (e.g., "grundlagen")
    let id: String

    /// Display title (e.g., "Grundlagen")
    let title: String

    /// Ordered list of topic IDs in this path
    let topicIds: [String]
}

/// The full index of all knowledge content, cached locally.
/// Built from the GitHub repo's folder structure, `_category.yml` files,
/// topic frontmatter, and `kanon.json`.
struct KnowledgeIndex: Codable, Equatable {
    /// All categories, sorted by `order`
    let categories: [KnowledgeCategory]

    /// All topics across all categories
    let topics: [KnowledgeTopic]

    /// Topic IDs marked as featured in `kanon.json`
    let featuredTopicIds: [String]

    /// Curated learning paths from `kanon.json`
    let learningPaths: [LearningPath]

    /// When this index was last fetched from GitHub
    let lastFetched: Date

    /// ETag from the last GitHub API response (for conditional requests)
    let etag: String?
}
