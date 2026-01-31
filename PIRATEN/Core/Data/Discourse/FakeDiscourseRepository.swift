//
//  FakeDiscourseRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Fake implementation of DiscourseRepository for development and testing.
/// Returns static in-memory data. Will be replaced by real Discourse API integration later.
///
/// No HTTP or WebSocket calls are made. All data is hardcoded for UI development.
@MainActor
final class FakeDiscourseRepository: DiscourseRepository {

    // MARK: - Stub Data

    /// Static fake users for stub content (placeholder data for development)
    private let fakeUsers: [UserSummary] = [
        UserSummary(
            id: 1,
            username: "nautilus",
            displayName: "Nautilus Navigator",
            avatarUrl: nil
        ),
        UserSummary(
            id: 2,
            username: "piratin_anna",
            displayName: "Anna B.",
            avatarUrl: nil
        ),
        UserSummary(
            id: 3,
            username: "digitale_freiheit",
            displayName: "Max Freiheit",
            avatarUrl: nil
        ),
        UserSummary(
            id: 4,
            username: "transparent_tim",
            displayName: "Tim Transparent",
            avatarUrl: nil
        )
    ]

    /// Static fake topics (placeholder data for development)
    private var fakeTopics: [Topic] {
        [
            Topic(
                id: 1,
                title: "Digitale Grundrechte: Aktuelle Entwicklungen in der EU",
                createdBy: fakeUsers[0],
                createdAt: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                postsCount: 15,
                viewCount: 234,
                likeCount: 42,
                categoryId: 1,
                isVisible: true,
                isClosed: false,
                isArchived: false
            ),
            Topic(
                id: 2,
                title: "Vorschlag: Transparenz-Initiative für Kommunalpolitik",
                createdBy: fakeUsers[1],
                createdAt: Date().addingTimeInterval(-86400 * 5), // 5 days ago
                postsCount: 28,
                viewCount: 456,
                likeCount: 67,
                categoryId: 2,
                isVisible: true,
                isClosed: false,
                isArchived: false
            ),
            Topic(
                id: 3,
                title: "Netzpolitischer Stammtisch - Termine 2026",
                createdBy: fakeUsers[2],
                createdAt: Date().addingTimeInterval(-86400 * 1), // 1 day ago
                postsCount: 8,
                viewCount: 123,
                likeCount: 19,
                categoryId: 3,
                isVisible: true,
                isClosed: false,
                isArchived: false
            ),
            Topic(
                id: 4,
                title: "Diskussion: Freie Software in Schulen fördern",
                createdBy: fakeUsers[3],
                createdAt: Date().addingTimeInterval(-86400 * 7), // 7 days ago
                postsCount: 45,
                viewCount: 789,
                likeCount: 112,
                categoryId: 1,
                isVisible: true,
                isClosed: false,
                isArchived: false
            ),
            Topic(
                id: 5,
                title: "Wahlkampf 2026: Materialien und Strategien",
                createdBy: fakeUsers[0],
                createdAt: Date().addingTimeInterval(-3600 * 6), // 6 hours ago
                postsCount: 3,
                viewCount: 45,
                likeCount: 8,
                categoryId: 4,
                isVisible: true,
                isClosed: false,
                isArchived: false
            )
        ]
    }

    /// Static fake posts for topic 1 (placeholder data for development)
    private var fakePostsForTopic1: [Post] {
        [
            Post(
                id: 101,
                topicId: 1,
                postNumber: 1,
                author: fakeUsers[0],
                createdAt: Date().addingTimeInterval(-86400 * 2),
                content: "Die EU plant neue Regelungen zu digitalen Grundrechten. Lasst uns die aktuellen Entwicklungen diskutieren.",
                replyCount: 3,
                likeCount: 12,
                isRead: true
            ),
            Post(
                id: 102,
                topicId: 1,
                postNumber: 2,
                author: fakeUsers[1],
                createdAt: Date().addingTimeInterval(-86400 * 2 + 3600),
                content: "Besonders wichtig finde ich die Aspekte zur Datensouveränität. Hier müssen wir als Piraten klare Position beziehen.",
                replyCount: 1,
                likeCount: 8,
                isRead: true
            ),
            Post(
                id: 103,
                topicId: 1,
                postNumber: 3,
                author: fakeUsers[2],
                createdAt: Date().addingTimeInterval(-86400 * 1),
                content: "Ich arbeite gerade an einer Zusammenfassung der wichtigsten Punkte. Teile ich hier, sobald fertig.",
                replyCount: 0,
                likeCount: 5,
                isRead: false
            )
        ]
    }

    // MARK: - DiscourseRepository

    func fetchTopics() async throws -> [Topic] {
        // Simulate network delay (placeholder behavior)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        return fakeTopics
    }

    func fetchPosts(forTopicId topicId: Int) async throws -> [Post] {
        // Simulate network delay (placeholder behavior)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Only return posts for topic 1 in this fake implementation
        if topicId == 1 {
            return fakePostsForTopic1
        }
        return []
    }

    func fetchTopic(byId id: Int) async throws -> Topic {
        // Simulate network delay (placeholder behavior)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        guard let topic = fakeTopics.first(where: { $0.id == id }) else {
            throw DiscourseRepositoryError.loadFailed(message: "Topic nicht gefunden")
        }
        return topic
    }
}
