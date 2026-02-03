//
//  RecentRecipientsStore.swift
//  PIRATEN
//
//  Created by Claude Code on 02.02.26.
//

import Foundation

/// Protocol for storing recent message recipients.
/// Allows swapping implementations for testing.
protocol RecentRecipientsStorage {
    /// Returns the list of recent recipient usernames, most recent first.
    func getRecentRecipients() -> [String]

    /// Adds a username to the recent recipients list.
    /// Moves to front if already present. Trims to max count.
    func addRecipient(_ username: String)

    /// Clears all recent recipients (e.g., on logout).
    func clearAll()
}

/// UserDefaults-backed storage for recent message recipients.
///
/// Privacy considerations:
/// - Only stores usernames (public identifiers), no PII
/// - Stores up to 10 recent recipients
/// - Cleared on logout via clearAll()
///
/// Thread safety: All access goes through UserDefaults which is thread-safe.
final class RecentRecipientsStore: RecentRecipientsStorage {

    // MARK: - Constants

    private static let userDefaultsKey = "piraten_recent_recipients"
    private static let maxRecipients = 10

    // MARK: - Dependencies

    private let userDefaults: UserDefaults

    // MARK: - Initialization

    /// Creates a RecentRecipientsStore with the specified UserDefaults.
    /// - Parameter userDefaults: The UserDefaults instance to use (default: .standard)
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - RecentRecipientsStorage

    func getRecentRecipients() -> [String] {
        userDefaults.stringArray(forKey: Self.userDefaultsKey) ?? []
    }

    func addRecipient(_ username: String) {
        var recipients = getRecentRecipients()

        // Remove if already present (will be re-added at front)
        recipients.removeAll { $0 == username }

        // Insert at front
        recipients.insert(username, at: 0)

        // Trim to max count
        if recipients.count > Self.maxRecipients {
            recipients = Array(recipients.prefix(Self.maxRecipients))
        }

        userDefaults.set(recipients, forKey: Self.userDefaultsKey)
    }

    func clearAll() {
        userDefaults.removeObject(forKey: Self.userDefaultsKey)
    }
}
