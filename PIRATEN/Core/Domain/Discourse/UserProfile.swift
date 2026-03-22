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
    let gliederung: String?

    /// Display text for the user, preferring display name over username.
    /// Filters out placeholder values (e.g. "none none") that Discourse may
    /// store when SSO doesn't provide a real name.
    var displayText: String {
        if let name = displayName?.trimmingCharacters(in: .whitespaces),
           !name.isEmpty,
           name.lowercased() != "none",
           name.lowercased() != "none none" {
            return name
        }
        return username
    }
}
