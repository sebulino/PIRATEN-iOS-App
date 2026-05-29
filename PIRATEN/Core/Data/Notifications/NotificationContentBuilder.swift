//
//  NotificationContentBuilder.swift
//  PIRATEN
//
//  Created by Claude Code on 29.05.26.
//
//  Pure functions that turn the newest item of a source into item-specific
//  notification text. No I/O, no state, no actor isolation — trivially unit
//  testable. Each builder:
//
//    • selects the "newest" item with the SAME key the
//      BackgroundRefreshCoordinator uses to *detect* new activity
//      (`max(id)`, or `max(messageId)` for News). Using a different key
//      here would let detection fire on item A while the banner names item B.
//    • returns `nil` when the list is empty or the chosen item has no usable
//      title — the caller then falls back to the generic category text.
//
//  Wissen (knowledge) and Termine (events) have no builder on purpose: a
//  changed knowledge slug can't be named meaningfully, and event detection is
//  count-based so it can't identify *which* event is new (see
//  BackgroundRefreshCoordinator.pollEvents and THREAT_MODEL.md T-007).
//

import Foundation

/// Namespace for the per-source notification body builders.
enum NotificationContentBuilder {

    /// Forum: names the newest topic by id.
    /// → `Neuer Beitrag im Thema »<Titel>«`
    static func forum(from topics: [Topic]) -> NotificationContent? {
        guard let newest = topics.max(by: { $0.id < $1.id }) else { return nil }
        let title = newest.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        return NotificationContent(
            title: NotificationCategory.forum.title,
            body: "Neuer Beitrag im Thema »\(title)«",
            isLockscreenSensitive: false,
            // Same `newest` topic named in the body → a tap opens that topic.
            deepLink: .forumTopic(topicId: newest.id)
        )
    }

    /// Private messages: names the sender and subject of the newest thread by id.
    /// → `Neue Nachricht von <Absender>: »<Betreff>«`
    ///
    /// Marked lockscreen-sensitive: the sender + subject are private and rely
    /// on the iOS "Vorschau: Wenn entsperrt" default to stay hidden on a
    /// locked screen. Returns `nil` (→ generic) if either the subject or a
    /// usable sender name is missing.
    static func messages(from threads: [MessageThread]) -> NotificationContent? {
        guard let newest = threads.max(by: { $0.id < $1.id }) else { return nil }
        let subject = newest.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subject.isEmpty, let sender = senderName(for: newest) else { return nil }
        return NotificationContent(
            title: NotificationCategory.messages.title,
            body: "Neue Nachricht von \(sender): »\(subject)«",
            isLockscreenSensitive: true,
            // Same `newest` thread named in the body → a tap opens that thread.
            // The thread id is the Discourse topic id (PMs are topics). Only the
            // id travels in userInfo — sender/subject are never encoded there.
            deepLink: .messageThread(topicId: newest.id)
        )
    }

    /// Todos: names the newest task by id.
    /// → `Neue Aufgabe: »<Titel>«`
    static func todos(from todos: [Todo]) -> NotificationContent? {
        guard let newest = todos.max(by: { $0.id < $1.id }) else { return nil }
        let title = newest.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        return NotificationContent(
            title: NotificationCategory.todos.title,
            body: "Neue Aufgabe: »\(title)«",
            isLockscreenSensitive: false,
            // ToDos deliberately route to the tab only (no item deep link).
            deepLink: nil
        )
    }

    /// News: names the newest item by messageId.
    /// → `Neue Neuigkeit: »<Headline>«`
    static func news(from items: [NewsItem]) -> NotificationContent? {
        guard let newest = items.max(by: { $0.messageId < $1.messageId }) else { return nil }
        let headline = newest.headline.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !headline.isEmpty else { return nil }
        return NotificationContent(
            title: NotificationCategory.news.title,
            body: "Neue Neuigkeit: »\(headline)«",
            isLockscreenSensitive: false,
            // News routes to the sheet only (no per-item deep link).
            deepLink: nil
        )
    }

    // MARK: - Helpers

    /// Resolves a human-readable sender name for a message thread:
    /// display name first, then username, else `nil` (→ generic fallback).
    private static func senderName(for thread: MessageThread) -> String? {
        guard let poster = thread.lastPoster else { return nil }
        if let displayName = poster.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            return displayName
        }
        let username = poster.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return username.isEmpty ? nil : username
    }
}
