//
//  NewsCacheStore.swift
//  PIRATEN
//

import Foundation

/// UserDefaults-backed cache for news items.
///
/// The Rails backend aggregates Telegram messages. This cache persists
/// fetched items locally so the news feed remains available offline.
///
/// Privacy considerations:
/// - Only stores public news channel messages (not private data)
/// - Stored locally only, never synced
/// - Maximum 100 items retained to limit storage use
final class NewsCacheStore {

    // MARK: - Constants

    private static let userDefaultsKey = "piraten_news_cache_v2"
    private static let maxCachedItems = 100

    // MARK: - Dependencies

    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Public Methods

    /// Returns all cached items, sorted newest-first.
    func cachedItems() -> [NewsItem] {
        guard let data = userDefaults.data(forKey: Self.userDefaultsKey) else {
            return []
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let items = try decoder.decode([NewsItem].self, from: data)
            return items.sorted { $0.postedAt > $1.postedAt }
        } catch {
            userDefaults.removeObject(forKey: Self.userDefaultsKey)
            return []
        }
    }

    /// Saves items to the cache, keeping the most recent entries.
    func save(_ items: [NewsItem]) {
        let sorted = items.sorted { $0.postedAt > $1.postedAt }
        let trimmed = Array(sorted.prefix(Self.maxCachedItems))

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(trimmed) {
            userDefaults.set(data, forKey: Self.userDefaultsKey)
        }
    }

    /// Clears all cached items.
    func clearAll() {
        userDefaults.removeObject(forKey: Self.userDefaultsKey)
    }
}
