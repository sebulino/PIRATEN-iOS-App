//
//  UserSummary.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Domain model representing a minimal user summary.
/// Used when displaying author information in topics and posts.
///
/// This is independent of the Discourse API JSON shape - DTOs handle mapping.
/// Based on Discourse API's created_by and username fields in responses.
struct UserSummary: Identifiable, Equatable, Hashable {
    /// Unique identifier for the user
    let id: Int

    /// Username of the user
    let username: String

    /// Optional display name (may differ from username)
    let displayName: String?

    /// Optional URL to the user's avatar
    let avatarUrl: URL?
}
