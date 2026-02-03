//
//  MessageDraftStore.swift
//  PIRATEN
//
//  Created by Claude Code on 03.02.26.
//

import Foundation

/// A draft message that can be saved and restored.
/// Contains all data needed to restore an in-progress compose session.
struct MessageDraft: Codable, Equatable {
    /// Username of the selected recipient
    let recipientUsername: String

    /// Display name of the recipient (for UI, may be nil)
    let recipientDisplayName: String?

    /// The message subject
    let subject: String

    /// The message body text
    let body: String

    /// When the draft was last saved
    let savedAt: Date

    /// Whether the draft has meaningful content worth restoring.
    var hasContent: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Protocol for draft message storage operations.
/// Abstracts the storage mechanism for testability.
protocol MessageDraftStorage {
    /// Retrieves the saved draft, if any.
    /// - Returns: The saved draft or nil if no draft exists
    func getDraft() -> MessageDraft?

    /// Saves a draft message.
    /// Only one draft is stored at a time - this replaces any existing draft.
    /// - Parameter draft: The draft to save
    func saveDraft(_ draft: MessageDraft)

    /// Clears the saved draft.
    func clearDraft()
}

/// UserDefaults-backed implementation of MessageDraftStorage.
/// Stores a single draft message that persists across app restarts.
///
/// Privacy: Drafts contain user-composed message content. This is stored
/// locally only and cleared on successful send or explicit discard.
final class MessageDraftStore: MessageDraftStorage {

    // MARK: - Constants

    private static let userDefaultsKey = "piraten.messageDraft"

    // MARK: - Dependencies

    private let userDefaults: UserDefaults

    // MARK: - Initialization

    /// Creates a draft store with the specified UserDefaults instance.
    /// - Parameter userDefaults: The UserDefaults to use (defaults to standard)
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - MessageDraftStorage

    func getDraft() -> MessageDraft? {
        guard let data = userDefaults.data(forKey: Self.userDefaultsKey) else {
            return nil
        }

        do {
            let draft = try JSONDecoder().decode(MessageDraft.self, from: data)
            return draft
        } catch {
            // If decoding fails, clear the corrupted data
            clearDraft()
            return nil
        }
    }

    func saveDraft(_ draft: MessageDraft) {
        do {
            let data = try JSONEncoder().encode(draft)
            userDefaults.set(data, forKey: Self.userDefaultsKey)
        } catch {
            // Encoding failure is unexpected but we silently ignore
            // to avoid disrupting the user experience
        }
    }

    func clearDraft() {
        userDefaults.removeObject(forKey: Self.userDefaultsKey)
    }
}
