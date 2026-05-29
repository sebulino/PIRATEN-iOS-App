//
//  SystemAccounts.swift
//  PIRATEN
//
//  Created by Claude Code on 29.05.26.
//

import Foundation

/// Canonical list of Discourse usernames that represent automated / system
/// accounts rather than real Piraten.
///
/// Discourse ships several non-human accounts that send automated private
/// messages — most notably `discobot` (the onboarding tutorial bot, which
/// PMs every new user a welcome message) and `system` (administrative
/// notices). Because they appear as PM participants, they would otherwise
/// surface in any contact list built from message threads or user search,
/// e.g. as a phantom entry in "Letzte Kontakte" right after a member's first
/// login.
///
/// This is the single source of truth for that exclusion. Every surface that
/// presents Discourse users as potential *human* contacts — the dashboard's
/// recent contacts and the recipient picker's search results — runs candidate
/// usernames through `isSystem(_:)` so the rule stays consistent in one place.
///
/// Matching is case-insensitive: Discourse usernames are unique
/// case-insensitively and the API may echo a different case than the
/// canonical login.
enum SystemAccounts {

    /// Lowercased usernames of known automated/system accounts that must never
    /// be shown as a human contact.
    static let usernames: Set<String> = [
        "system",
        "discobot",
        "robotpirat",
    ]

    /// Returns `true` if `username` belongs to an automated/system account.
    /// Case-insensitive.
    static func isSystem(_ username: String) -> Bool {
        usernames.contains(username.lowercased())
    }
}
