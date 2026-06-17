//
//  Topic.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Domain model representing a forum topic.
/// This is independent of the Discourse API JSON shape - DTOs handle mapping.
///
/// Based on Discourse API concepts but intentionally simplified for our domain needs.
/// See: Discourse API /t/{topic_id}.json response structure
struct Topic: Identifiable, Equatable, Hashable, Codable {
    /// Unique identifier for the topic
    let id: Int

    /// Title of the topic
    let title: String

    /// Summary of the user who created this topic
    let createdBy: UserSummary

    /// When the topic was created
    let createdAt: Date

    /// When the most recent post arrived (Discourse `bumped_at`). Optional:
    /// older cached topics predate this field and decode as `nil`, and a topic
    /// JSON without it falls back to `createdAt` at the display site.
    let lastActivityAt: Date?

    /// Total number of posts in this topic
    let postsCount: Int

    /// Number of views this topic has received
    let viewCount: Int

    /// Number of likes this topic has received
    let likeCount: Int

    /// Identifier of the category this topic belongs to
    let categoryId: Int

    /// Whether the topic is currently visible
    let isVisible: Bool

    /// Whether the topic is closed for new replies
    let isClosed: Bool

    /// Whether the topic has been archived
    let isArchived: Bool

    /// Whether the topic has been read by the current user
    let isRead: Bool

    /// `lastActivityAt` defaults to `nil` so the many existing call sites
    /// (fakes, tests) that don't supply it keep compiling; the DTO mapping and
    /// `markedRead()` pass it explicitly.
    init(
        id: Int,
        title: String,
        createdBy: UserSummary,
        createdAt: Date,
        lastActivityAt: Date? = nil,
        postsCount: Int,
        viewCount: Int,
        likeCount: Int,
        categoryId: Int,
        isVisible: Bool,
        isClosed: Bool,
        isArchived: Bool,
        isRead: Bool
    ) {
        self.id = id
        self.title = title
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.postsCount = postsCount
        self.viewCount = viewCount
        self.likeCount = likeCount
        self.categoryId = categoryId
        self.isVisible = isVisible
        self.isClosed = isClosed
        self.isArchived = isArchived
        self.isRead = isRead
    }
}

extension Topic {
    /// Returns a copy marked as read. Used when the user opens a topic so the
    /// list surfaces that show an unread / "Neu" cue (forum list, the Kajüte's
    /// "Aktuelle Themen") drop it. Centralised here so every read-flip stays in
    /// sync — `Topic` is an all-`let` value type, so the fields must otherwise
    /// be re-listed by hand at each call site.
    func markedRead() -> Topic {
        Topic(
            id: id,
            title: title,
            createdBy: createdBy,
            createdAt: createdAt,
            lastActivityAt: lastActivityAt,
            postsCount: postsCount,
            viewCount: viewCount,
            likeCount: likeCount,
            categoryId: categoryId,
            isVisible: isVisible,
            isClosed: isClosed,
            isArchived: isArchived,
            isRead: true
        )
    }
}
