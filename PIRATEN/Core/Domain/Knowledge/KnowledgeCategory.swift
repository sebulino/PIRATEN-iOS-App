//
//  KnowledgeCategory.swift
//  PIRATEN
//

import Foundation

/// A category grouping related knowledge topics (e.g., "Kommunalpolitik").
/// Maps to a folder in the PIRATEN-Kanon GitHub repo with a `_category.yml` descriptor.
struct KnowledgeCategory: Identifiable, Equatable, Codable {
    /// Unique identifier (matches folder name, e.g., "kommunalpolitik")
    let id: String

    /// Display title (e.g., "Kommunalpolitik")
    let title: String

    /// Short description of the category
    let description: String

    /// Sort order (lower = first)
    let order: Int

    /// SF Symbol name for display (e.g., "building.2")
    let icon: String
}
