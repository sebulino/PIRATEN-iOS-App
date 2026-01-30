//
//  Post.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Domain model representing a forum post.
/// This is independent of the Discourse API JSON shape - DTOs handle mapping.
///
/// Based on Discourse API concepts but intentionally simplified for our domain needs.
/// See: Discourse API post objects in /t/{topic_id}.json and /posts.json responses
struct Post: Identifiable, Equatable {
    /// Unique identifier for the post
    let id: Int

    /// The topic this post belongs to
    let topicId: Int

    /// Sequential number of this post within its topic
    let postNumber: Int

    /// Summary of the user who wrote this post
    let author: UserSummary

    /// When the post was created
    let createdAt: Date

    /// The content of the post (plain text or sanitized HTML, depending on use case)
    /// Note: Discourse returns 'cooked' (rendered HTML). Our domain stores content
    /// in a format suitable for display - the data layer handles any transformation.
    let content: String

    /// Number of replies to this post
    let replyCount: Int

    /// Number of likes this post has received
    let likeCount: Int

    /// Whether this post has been read by the current user
    let isRead: Bool
}
