import Foundation

/// Represents a full user profile fetched from Discourse.
/// Separate from UserSummary to provide richer profile data.
struct UserProfile: Identifiable, Equatable {
    let id: Int
    let username: String
    let displayName: String?
    let avatarUrl: URL?
    let bio: String?
    let joinedAt: Date
    let postCount: Int
    let likesGiven: Int
    let likesReceived: Int

    /// Display text for the user, preferring display name over username
    var displayText: String {
        displayName ?? username
    }
}
