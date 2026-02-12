//
//  ReadingProgressStore.swift
//  PIRATEN
//
//  Created by Claude Code on 12.02.26.
//

import Foundation

/// Protocol for persisting Knowledge Hub reading progress.
/// Allows swapping implementations for testing.
protocol ReadingProgressStorage {
    /// Returns progress for a specific topic, or nil if no progress recorded.
    func getProgress(for topicId: String) -> TopicProgress?

    /// Returns all persisted progress entries.
    func getAllProgress() -> [String: TopicProgress]

    /// Saves progress for a topic, creating or updating.
    func saveProgress(_ progress: TopicProgress)

    /// Clears all progress (e.g., on logout).
    func clearAll()
}

/// UserDefaults-backed storage for knowledge topic reading progress.
///
/// Privacy considerations:
/// - Only stores topic IDs (not content) and completion state
/// - No PII or user-identifiable data
/// - Stored locally only, never synced
/// - Cleared on logout via clearAll()
///
/// Thread safety: All access goes through UserDefaults which is thread-safe.
final class ReadingProgressStore: ReadingProgressStorage {

    // MARK: - Constants

    private static let userDefaultsKey = "piraten_knowledge_progress"

    // MARK: - Dependencies

    private let userDefaults: UserDefaults

    // MARK: - Initialization

    /// Creates a ReadingProgressStore with the specified UserDefaults.
    /// - Parameter userDefaults: The UserDefaults instance to use (default: .standard)
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - ReadingProgressStorage

    func getProgress(for topicId: String) -> TopicProgress? {
        let allProgress = getAllProgress()
        return allProgress[topicId]
    }

    func getAllProgress() -> [String: TopicProgress] {
        guard let data = userDefaults.data(forKey: Self.userDefaultsKey) else {
            return [:]
        }
        do {
            return try JSONDecoder().decode([String: TopicProgress].self, from: data)
        } catch {
            // Silently clear corrupted data
            userDefaults.removeObject(forKey: Self.userDefaultsKey)
            return [:]
        }
    }

    func saveProgress(_ progress: TopicProgress) {
        var allProgress = getAllProgress()
        allProgress[progress.topicId] = progress
        if let data = try? JSONEncoder().encode(allProgress) {
            userDefaults.set(data, forKey: Self.userDefaultsKey)
        }
    }

    func clearAll() {
        userDefaults.removeObject(forKey: Self.userDefaultsKey)
    }
}
