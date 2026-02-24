//
//  NewsRepository.swift
//  PIRATEN
//

import Foundation

/// Repository protocol for fetching news posts.
@MainActor
protocol NewsRepository {
    /// Fetches news posts, returning cached posts merged with any new ones.
    /// Sorted newest-first.
    func fetchNews() async throws -> [NewsPost]
}
