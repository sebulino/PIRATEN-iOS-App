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
struct Topic: Identifiable, Equatable, Hashable {
    /// Unique identifier for the topic
    let id: Int

    /// Title of the topic
    let title: String

    /// Summary of the user who created this topic
    let createdBy: UserSummary

    /// When the topic was created
    let createdAt: Date

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
}
