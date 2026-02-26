//
//  NewsRepository.swift
//  PIRATEN
//

import Foundation

/// Repository protocol for fetching news items.
@MainActor
protocol NewsRepository {
    /// Fetches news items, returning cached items merged with any new ones.
    /// Sorted newest-first.
    func fetchNews() async throws -> [NewsItem]
}
