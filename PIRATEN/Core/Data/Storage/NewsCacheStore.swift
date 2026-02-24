//
//  NewsCacheStore.swift
//  PIRATEN
//

import Foundation

/// UserDefaults-backed cache for Telegram news posts.
///
/// The Telegram Bot API `getUpdates` only stores unprocessed updates for 24 hours.
/// This cache persists fetched posts locally so the news feed remains available.
///
/// Privacy considerations:
/// - Only stores public news channel messages (not private data)
/// - Stored locally only, never synced
/// - Maximum 100 posts retained to limit storage use
final class NewsCacheStore {

    // MARK: - Constants

    private static let userDefaultsKey = "piraten_news_cache"
    private static let maxCachedPosts = 100

    // MARK: - Dependencies

    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Public Methods

    /// Returns all cached posts, sorted newest-first.
    func cachedPosts() -> [NewsPost] {
        guard let data = userDefaults.data(forKey: Self.userDefaultsKey) else {
            return []
        }
        do {
            let posts = try JSONDecoder().decode([NewsPost].self, from: data)
            return posts.sorted { $0.date > $1.date }
        } catch {
            userDefaults.removeObject(forKey: Self.userDefaultsKey)
            return []
        }
    }

    /// Merges new posts with cached posts, deduplicating by ID.
    /// Keeps the most recent 100 posts.
    func merge(_ newPosts: [NewsPost]) {
        var existing = cachedPosts()
        let existingIds = Set(existing.map { $0.id })

        for post in newPosts where !existingIds.contains(post.id) {
            existing.append(post)
        }

        let sorted = existing.sorted { $0.date > $1.date }
        let trimmed = Array(sorted.prefix(Self.maxCachedPosts))

        save(trimmed)
    }

    /// Saves posts to the cache.
    func save(_ posts: [NewsPost]) {
        if let data = try? JSONEncoder().encode(posts) {
            userDefaults.set(data, forKey: Self.userDefaultsKey)
        }
    }

    /// Clears all cached posts.
    func clearAll() {
        userDefaults.removeObject(forKey: Self.userDefaultsKey)
    }
}
