//
//  DiscourseCacheStore.swift
//  PIRATEN
//

import Foundation

/// UserDefaults-backed cache for Discourse API responses (topics and message threads).
///
/// Persists fetched items locally so the app can show content immediately at startup
/// while fresh data loads in the background. This reduces the number of simultaneous
/// Discourse API requests and avoids rate limiting (429 errors).
///
/// Privacy considerations:
/// - Only stores forum topics and message thread metadata (not message content)
/// - Stored locally only, never synced
/// - Maximum 50 items per type retained to limit storage use
final class DiscourseCacheStore {

    // MARK: - Constants

    private static let topicsCacheKey = "piraten_discourse_topics_cache_v1"
    private static let messagesCacheKey = "piraten_discourse_messages_cache_v1"
    private static let maxCachedItems = 50

    // MARK: - Dependencies

    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Topics

    /// Returns cached forum topics, sorted newest-first.
    func cachedTopics() -> [Topic] {
        return decode(forKey: Self.topicsCacheKey) ?? []
    }

    /// Saves forum topics to the cache, keeping the most recent entries.
    func saveTopics(_ topics: [Topic]) {
        let trimmed = Array(topics.prefix(Self.maxCachedItems))
        encode(trimmed, forKey: Self.topicsCacheKey)
    }

    // MARK: - Message Threads

    /// Returns cached message threads, sorted by last activity.
    func cachedMessageThreads() -> [MessageThread] {
        return decode(forKey: Self.messagesCacheKey) ?? []
    }

    /// Saves message threads to the cache, keeping the most recent entries.
    func saveMessageThreads(_ threads: [MessageThread]) {
        let trimmed = Array(threads.prefix(Self.maxCachedItems))
        encode(trimmed, forKey: Self.messagesCacheKey)
    }

    // MARK: - Maintenance

    /// Clears all cached Discourse data.
    func clearAll() {
        userDefaults.removeObject(forKey: Self.topicsCacheKey)
        userDefaults.removeObject(forKey: Self.messagesCacheKey)
    }

    // MARK: - Private Helpers

    private func decode<T: Decodable>(forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            userDefaults.removeObject(forKey: key)
            return nil
        }
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(value) {
            userDefaults.set(data, forKey: key)
        }
    }
}
