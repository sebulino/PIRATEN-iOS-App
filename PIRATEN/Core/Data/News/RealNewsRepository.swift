//
//  RealNewsRepository.swift
//  PIRATEN
//

import Foundation

/// Production implementation of NewsRepository.
/// Fetches news from the meine-piraten.de Rails backend with offline cache fallback.
@MainActor
final class RealNewsRepository: NewsRepository {

    // MARK: - Dependencies

    private let apiClient: NewsAPIClient
    private let cache: NewsCacheStore

    // MARK: - Initialization

    init(apiClient: NewsAPIClient, cache: NewsCacheStore) {
        self.apiClient = apiClient
        self.cache = cache
    }

    // MARK: - NewsRepository

    func fetchNews() async throws -> [NewsItem] {
        do {
            let items = try await apiClient.fetchNews()
            cache.save(items)
            return items
        } catch {
            let cached = cache.cachedItems()
            if !cached.isEmpty {
                return cached
            }
            throw error
        }
    }
}
