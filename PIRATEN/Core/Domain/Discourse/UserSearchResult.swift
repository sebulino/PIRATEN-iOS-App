//
//  UserSearchResult.swift
//  PIRATEN
//
//  Created by Claude Code on 02.02.26.
//

import Foundation

/// Represents a user returned from the Discourse user search API.
/// Used for selecting recipients when composing new private messages.
///
/// This is a lightweight model containing only the fields needed for
/// the recipient picker UI: username, display name, and avatar.
struct UserSearchResult: Identifiable, Equatable, Hashable {
    /// Unique identifier - uses username since it's unique in Discourse
    var id: String { username }

    /// The user's unique username (used for API calls)
    let username: String

    /// Optional display name (shown in UI, falls back to username)
    let displayName: String?

    /// Optional URL to the user's avatar image
    let avatarUrl: URL?

    /// Returns the best name to display: displayName if available, otherwise username
    var displayText: String {
        displayName ?? username
    }
}
