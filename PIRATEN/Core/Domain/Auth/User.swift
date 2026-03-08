//
//  User.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Domain model representing an authenticated user.
/// This model is independent of the SSO provider's response format.
///
/// Note: This is PLACEHOLDER DATA for development. Real user information will
/// come from Piratenlogin SSO once integrated. See Docs/OPEN_QUESTIONS.md for
/// details on the pending SSO integration.
struct User: Identifiable, Equatable {
    /// Unique identifier for the user
    let id: String

    /// User's username (typically used for login)
    let username: String

    /// User's display name (shown in the UI)
    let displayName: String

    /// User's email address
    let email: String

    /// URL to user's avatar image (optional)
    let avatarUrl: URL?

    /// Date when the user joined the party
    let memberSince: Date?

    /// Name of the user's local/regional group (e.g., "Kreisverband München")
    let localGroupName: String?

    /// Name of the state association (e.g., "Landesverband Bayern")
    let stateAssociationName: String?

    /// Party membership number (from Keycloak custom claim)
    let memberNumber: String?
}
