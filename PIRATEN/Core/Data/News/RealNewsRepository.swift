//
//  RealNewsRepository.swift
//  PIRATEN
//

import Foundation

/// Production implementation of NewsRepository.
/// Fetches messages from the Telegram Bot API and merges with local cache.
@MainActor
final class RealNewsRepository: NewsRepository {

    // MARK: - Dependencies

    private let apiClient: TelegramAPIClient
    private let cache: NewsCacheStore

    // MARK: - Initialization

    init(apiClient: TelegramAPIClient, cache: NewsCacheStore) {
        self.apiClient = apiClient
        self.cache = cache
    }

    // MARK: - NewsRepository

    func fetchNews() async throws -> [NewsPost] {
        let freshPosts = try await apiClient.fetchMessages()
        cache.merge(freshPosts)
        return cache.cachedPosts()
    }
}
