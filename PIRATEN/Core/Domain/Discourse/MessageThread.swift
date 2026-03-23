//
//  MessageThread.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

/// Domain model representing a private message thread.
/// This maps from Discourse's topic with archetype 'private_message'.
///
/// In Discourse, private messages are essentially topics with:
/// - archetype = "private_message"
/// - A list of participants instead of a category
/// - Same post structure as regular topics
///
/// API Reference: GET /topics/private-messages/{username}.json
struct MessageThread: Identifiable, Equatable, Hashable {
    /// Unique identifier for the message thread (same as topic ID in Discourse)
    let id: Int

    /// Subject/title of the message thread
    let title: String

    /// Participants in this message thread
    let participants: [UserSummary]

    /// When the thread was created
    let createdAt: Date

    /// When the last post was added to this thread
    let lastActivityAt: Date

    /// Number of posts/messages in this thread
    let postsCount: Int

    /// Whether the thread has been read by the current user
    let isRead: Bool

    /// The last poster in the thread (for preview display)
    let lastPoster: UserSummary?
}
