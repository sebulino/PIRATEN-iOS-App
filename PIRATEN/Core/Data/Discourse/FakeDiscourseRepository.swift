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

    /// Static fake posts for message thread 1001 (placeholder data for PM detail view)
    private var fakePostsForMessageThread1001: [Post] {
        [
            Post(
                id: 10001,
                topicId: 1001,
                postNumber: 1,
                author: fakeUsers[0],
                createdAt: Date().addingTimeInterval(-86400 * 3),
                content: "Hallo zusammen, wir müssen noch die Agenda für die Bundesvorstandssitzung abstimmen. Hat jemand Vorschläge?",
                replyCount: 2,
                likeCount: 0,
                isRead: true
            ),
            Post(
                id: 10002,
                topicId: 1001,
                postNumber: 2,
                author: fakeUsers[1],
                createdAt: Date().addingTimeInterval(-86400 * 3 + 7200),
                content: "Ich würde gerne den Punkt 'Digitalisierungsstrategie' auf die Agenda setzen. Das Thema wird immer dringender.",
                replyCount: 1,
                likeCount: 0,
                isRead: true
            ),
            Post(
                id: 10003,
                topicId: 1001,
                postNumber: 3,
                author: fakeUsers[0],
                createdAt: Date().addingTimeInterval(-3600 * 2),
                content: "Guter Vorschlag! Ich nehme das auf. Gibt es weitere Punkte?",
                replyCount: 0,
                likeCount: 0,
                isRead: true
            )
        ]
    }

    /// Static fake posts for message thread 1002 (placeholder data for PM detail view)
    private var fakePostsForMessageThread1002: [Post] {
        [
            Post(
                id: 10101,
                topicId: 1002,
                postNumber: 1,
                author: fakeUsers[0],
                createdAt: Date().addingTimeInterval(-86400 * 7),
                content: "Der LPT Bayern steht an. Wir müssen noch die Räumlichkeiten organisieren.",
                replyCount: 0,
                likeCount: 0,
                isRead: true
            ),
            Post(
                id: 10102,
                topicId: 1002,
                postNumber: 2,
                author: fakeUsers[2],
                createdAt: Date().addingTimeInterval(-86400 * 1),
                content: "Ich habe eine Location in München gefunden. Details im Anhang.",
                replyCount: 0,
                likeCount: 0,
                isRead: false
            )
        ]
    }

    /// Static fake message threads (placeholder data for development)
    private var fakeMessageThreads: [MessageThread] {
        [
            MessageThread(
                id: 1001,
                title: "Abstimmung zur Bundesvorstandssitzung",
                participants: [fakeUsers[0], fakeUsers[1]],
                createdAt: Date().addingTimeInterval(-86400 * 3),
                lastActivityAt: Date().addingTimeInterval(-3600 * 2),
                postsCount: 5,
                isRead: true,
                lastPoster: fakeUsers[1]
            ),
            MessageThread(
                id: 1002,
                title: "Organisatorisches LPT Bayern",
                participants: [fakeUsers[0], fakeUsers[2], fakeUsers[3]],
                createdAt: Date().addingTimeInterval(-86400 * 7),
                lastActivityAt: Date().addingTimeInterval(-86400 * 1),
                postsCount: 12,
                isRead: false,
                lastPoster: fakeUsers[2]
            ),
            MessageThread(
                id: 1003,
                title: "Presseanfrage lokale Zeitung",
                participants: [fakeUsers[0], fakeUsers[3]],
                createdAt: Date().addingTimeInterval(-86400 * 2),
                lastActivityAt: Date().addingTimeInterval(-86400 * 2),
                postsCount: 2,
                isRead: true,
                lastPoster: fakeUsers[3]
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

        // Return posts for known topic/message thread IDs
        switch topicId {
        case 1:
            return fakePostsForTopic1
        case 1001:
            return fakePostsForMessageThread1001
        case 1002:
            return fakePostsForMessageThread1002
        default:
            return []
        }
    }

    func fetchTopic(byId id: Int) async throws -> Topic {
        // Simulate network delay (placeholder behavior)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        guard let topic = fakeTopics.first(where: { $0.id == id }) else {
            throw DiscourseRepositoryError.loadFailed(message: "Topic nicht gefunden")
        }
        return topic
    }

    func fetchMessageThreads(for username: String) async throws -> [MessageThread] {
        // Simulate network delay (placeholder behavior)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        return fakeMessageThreads
    }

    func replyToThread(topicId: Int, content: String) async throws {
        // Simulate network delay (placeholder behavior)
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        // For fake implementation, we don't actually persist the reply
        // A real integration test would verify behavior differently
    }

    func searchUsers(query: String) async throws -> [UserSearchResult] {
        // Simulate network delay (placeholder behavior)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Enforce minimum query length
        guard query.count >= 2 else {
            return []
        }

        // Convert fake users to search results and filter by query
        let allResults = fakeUsers.map { user in
            UserSearchResult(
                username: user.username,
                displayName: user.displayName,
                avatarUrl: user.avatarUrl
            )
        }

        // Filter by query (case-insensitive match on username or display name)
        let lowercasedQuery = query.lowercased()
        return allResults.filter { result in
            result.username.lowercased().contains(lowercasedQuery) ||
            (result.displayName?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }

    func createPrivateMessage(recipient: String, title: String, content: String) async throws {
        // Simulate network delay (placeholder behavior)
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        // For fake implementation, we don't actually create the message
    }
}
