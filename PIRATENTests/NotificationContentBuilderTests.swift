//
//  NotificationContentBuilderTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 29.05.26.
//
//  Unit tests for the pure per-source notification body builders and the
//  scheduler's generic-fallback contract. The privacy test is the headline
//  case: the messages builder must name the sender, while the generic
//  fallback must NOT (see THREAT_MODEL.md T-007).
//

import Foundation
import Testing
@testable import PIRATEN

@Suite("NotificationContentBuilder Tests")
struct NotificationContentBuilderTests {

    // MARK: - Model factories

    private func makeUser(
        id: Int = 1,
        username: String = "pirat",
        displayName: String? = nil
    ) -> UserSummary {
        UserSummary(id: id, username: username, displayName: displayName, avatarUrl: nil)
    }

    private func makeTopic(id: Int, title: String) -> Topic {
        Topic(
            id: id,
            title: title,
            createdBy: makeUser(),
            createdAt: Date(),
            postsCount: 1,
            viewCount: 0,
            likeCount: 0,
            categoryId: 1,
            isVisible: true,
            isClosed: false,
            isArchived: false,
            isRead: false
        )
    }

    private func makeThread(
        id: Int,
        title: String,
        lastPoster: UserSummary?
    ) -> MessageThread {
        MessageThread(
            id: id,
            title: title,
            participants: lastPoster.map { [$0] } ?? [],
            createdAt: Date(),
            lastActivityAt: Date(),
            postsCount: 1,
            isRead: false,
            lastPoster: lastPoster
        )
    }

    private func makeTodo(id: Int, title: String) -> Todo {
        Todo(
            id: id,
            title: title,
            description: nil,
            entityId: 0,
            categoryId: 0,
            createdAt: Date(),
            dueDate: nil,
            status: .open,
            assignee: nil,
            urgent: false,
            activityPoints: nil,
            timeNeededInHours: nil,
            creatorName: nil
        )
    }

    private func makeNews(messageId: Int64, text: String) -> NewsItem {
        NewsItem(chatId: 1, messageId: messageId, postedAt: Date(), text: text)
    }

    // MARK: - Forum

    @Test("Forum builder names the newest topic with guillemets")
    func forumBuildsExactString() {
        let content = NotificationContentBuilder.forum(from: [
            makeTopic(id: 1, title: "Altes Thema"),
            makeTopic(id: 9, title: "Mitgliederversammlung 2026")
        ])
        #expect(content?.body == "Neuer Beitrag im Thema »Mitgliederversammlung 2026«")
        #expect(content?.title == NotificationCategory.forum.title)
        #expect(content?.isLockscreenSensitive == false)
    }

    @Test("Forum builder picks the highest id, not array order")
    func forumPicksMaxId() {
        // Highest id (42) is first in the array → max(id), not first/last.
        let content = NotificationContentBuilder.forum(from: [
            makeTopic(id: 42, title: "Gewinner"),
            makeTopic(id: 7, title: "Verlierer")
        ])
        #expect(content?.body.contains("»Gewinner«") == true)
    }

    @Test("Forum builder returns nil for empty list")
    func forumEmptyIsNil() {
        #expect(NotificationContentBuilder.forum(from: []) == nil)
    }

    @Test("Forum builder returns nil when title is blank")
    func forumBlankTitleIsNil() {
        #expect(NotificationContentBuilder.forum(from: [makeTopic(id: 1, title: "   ")]) == nil)
    }

    // MARK: - Messages (privacy)

    @Test("Messages builder names sender and subject and is lockscreen-sensitive")
    func messagesBuildsExactStringAndIsSensitive() {
        let sender = makeUser(username: "kraehe", displayName: "Käpt'n Krähe")
        let content = NotificationContentBuilder.messages(from: [
            makeThread(id: 5, title: "Klarmachen zum Entern", lastPoster: sender)
        ])
        #expect(content?.body == "Neue Nachricht von Käpt'n Krähe: »Klarmachen zum Entern«")
        #expect(content?.title == NotificationCategory.messages.title)
        #expect(content?.isLockscreenSensitive == true)
    }

    @Test("PRIVACY: messages body contains the sender; generic fallback does not")
    func messagesPrivacyContract() {
        let sender = makeUser(username: "geheim_pirat", displayName: "Geheimer Pirat")
        let content = NotificationContentBuilder.messages(from: [
            makeThread(id: 1, title: "Vertraulich", lastPoster: sender)
        ])
        // Item-specific body reveals the sender (only shown when unlocked).
        #expect(content?.body.contains("Geheimer Pirat") == true)
        // The generic fallback must never name a sender.
        #expect(NotificationCategory.messages.body.contains("Geheimer Pirat") == false)
        #expect(NotificationCategory.messages.body == "Du hast neue private Nachrichten.")
    }

    @Test("Messages builder falls back to username when display name is missing")
    func messagesUsesUsernameFallback() {
        let sender = makeUser(username: "nur_username", displayName: nil)
        let content = NotificationContentBuilder.messages(from: [
            makeThread(id: 1, title: "Betreff", lastPoster: sender)
        ])
        #expect(content?.body == "Neue Nachricht von nur_username: »Betreff«")
    }

    @Test("Messages builder returns nil when sender is unknown")
    func messagesNoSenderIsNil() {
        let content = NotificationContentBuilder.messages(from: [
            makeThread(id: 1, title: "Betreff ohne Absender", lastPoster: nil)
        ])
        #expect(content == nil)
    }

    @Test("Messages builder returns nil for empty list")
    func messagesEmptyIsNil() {
        #expect(NotificationContentBuilder.messages(from: []) == nil)
    }

    // MARK: - Todos

    @Test("Todos builder names the newest task")
    func todosBuildsExactString() {
        let content = NotificationContentBuilder.todos(from: [
            makeTodo(id: 1, title: "Alt"),
            makeTodo(id: 3, title: "Flyer verteilen")
        ])
        #expect(content?.body == "Neue Aufgabe: »Flyer verteilen«")
        #expect(content?.isLockscreenSensitive == false)
    }

    @Test("Todos builder returns nil for empty list")
    func todosEmptyIsNil() {
        #expect(NotificationContentBuilder.todos(from: []) == nil)
    }

    // MARK: - News

    @Test("News builder names the newest headline by messageId")
    func newsBuildsExactString() {
        let content = NotificationContentBuilder.news(from: [
            makeNews(messageId: 10, text: "Alte Meldung"),
            makeNews(messageId: 20, text: "<sebulino> Stammtisch am Freitag")
        ])
        // displayText strips the <sender> marker; headline is the first line.
        #expect(content?.body == "Neue Neuigkeit: »Stammtisch am Freitag«")
        #expect(content?.isLockscreenSensitive == false)
    }

    @Test("News builder returns nil for empty list")
    func newsEmptyIsNil() {
        #expect(NotificationContentBuilder.news(from: []) == nil)
    }

    // MARK: - Scheduler contract

    @Test("Convenience schedule(_:) forwards nil content (generic path)")
    func convenienceOverloadForwardsNil() async {
        let spy = SpyNotificationScheduler()
        await spy.schedule(.knowledge)
        #expect(spy.calls.count == 1)
        #expect(spy.calls.first?.category == .knowledge)
        #expect(spy.calls.first?.content == nil)
    }

    @Test("schedule(_:content:) passes the content through unchanged")
    func explicitContentPassesThrough() async {
        let spy = SpyNotificationScheduler()
        let content = NotificationContent(title: "T", body: "B", isLockscreenSensitive: true, deepLink: nil)
        await spy.schedule(.forum, content: content)
        #expect(spy.calls.last?.content == content)
    }

    // MARK: - Deep link payload (tap → exact item)

    @Test("Forum builder deep-links to the newest topic (same item as the body)")
    func forumDeepLinksToNamedTopic() {
        let content = NotificationContentBuilder.forum(from: [
            makeTopic(id: 7, title: "Verlierer"),
            makeTopic(id: 42, title: "Mitgliederversammlung 2026")
        ])
        // The deep link targets the SAME topic named in the body (max id = 42),
        // so a tap can never open a different topic than the banner advertised.
        #expect(content?.deepLink == .forumTopic(topicId: 42))
        #expect(content?.body.contains("»Mitgliederversammlung 2026«") == true)
    }

    @Test("Messages builder deep-links to the newest thread (same item as the body)")
    func messagesDeepLinksToNamedThread() {
        let sender = makeUser(username: "kraehe", displayName: "Käpt'n Krähe")
        let content = NotificationContentBuilder.messages(from: [
            makeThread(id: 3, title: "Alt", lastPoster: sender),
            makeThread(id: 99, title: "Klarmachen zum Entern", lastPoster: sender)
        ])
        #expect(content?.deepLink == .messageThread(topicId: 99))
        #expect(content?.body.contains("»Klarmachen zum Entern«") == true)
    }

    @Test("Todos builder sets no deep link (tab-level routing only)")
    func todosHasNoDeepLink() {
        let content = NotificationContentBuilder.todos(from: [makeTodo(id: 1, title: "Aufgabe")])
        #expect(content != nil)
        #expect(content?.deepLink == nil)
    }

    @Test("News builder sets no deep link (sheet routing only)")
    func newsHasNoDeepLink() {
        let content = NotificationContentBuilder.news(from: [makeNews(messageId: 1, text: "Neuigkeit")])
        #expect(content != nil)
        #expect(content?.deepLink == nil)
    }
}

/// In-memory scheduler that records calls instead of touching
/// `UNUserNotificationCenter`. Reusable by future notification tests.
final class SpyNotificationScheduler: LocalNotificationScheduling, @unchecked Sendable {
    struct Call: Equatable {
        let category: NotificationCategory
        let content: NotificationContent?
    }

    private(set) var calls: [Call] = []

    func schedule(_ category: NotificationCategory, content: NotificationContent?) async {
        calls.append(Call(category: category, content: content))
    }
}
