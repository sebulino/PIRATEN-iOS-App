//
//  ComposeMessageViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 02.02.26.
//

import Foundation
import Combine

/// State of the compose message process.
enum ComposeMessageState: Equatable {
    case idle
    case sending
    case sent(topicId: Int)  // Include topic ID for navigation to new thread
    case failed(message: String)
}

/// ViewModel for composing a new private message.
/// Handles recipient, subject, body, safety validation, and draft persistence.
@MainActor
final class ComposeMessageViewModel: ObservableObject, Identifiable {
    let id = UUID()

    // MARK: - Published State

    /// The selected recipient
    @Published var recipient: UserSearchResult?

    /// The message subject (required)
    @Published var subject: String = ""

    /// The message body content
    @Published var bodyText: String = ""

    /// Current state of the compose process
    @Published private(set) var state: ComposeMessageState = .idle

    /// Validation error message for the body (from safety service)
    @Published private(set) var validationErrorMessage: String?

    /// Whether a saved draft is available for restoration
    @Published private(set) var hasPendingDraft: Bool = false

    /// The pending draft (for display in restore prompt)
    private(set) var pendingDraft: MessageDraft?

    // MARK: - Dependencies

    private let discourseRepository: DiscourseRepository
    private let safetyService: MessageSafetyService
    private let recentRecipientsStorage: RecentRecipientsStorage
    private let draftStorage: MessageDraftStorage

    // MARK: - Initialization

    init(
        discourseRepository: DiscourseRepository,
        safetyService: MessageSafetyService? = nil,
        recentRecipientsStorage: RecentRecipientsStorage,
        draftStorage: MessageDraftStorage? = nil
    ) {
        self.discourseRepository = discourseRepository
        self.safetyService = safetyService ?? MessageSafetyService()
        self.recentRecipientsStorage = recentRecipientsStorage
        self.draftStorage = draftStorage ?? MessageDraftStore()
    }

    // MARK: - Computed Properties

    /// Whether the message can be sent (valid recipient, subject, and body)
    var canSend: Bool {
        guard recipient != nil else { return false }
        guard !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        let validation = safetyService.validate(content: bodyText)
        return validation.isValid && state != .sending && safetyService.canSend()
    }

    /// Whether there is any content to lose (for cancel confirmation)
    var hasContent: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Character count info for the body
    var characterCountInfo: (current: Int, max: Int, isOverLimit: Bool) {
        safetyService.characterCount(for: bodyText)
    }

    /// Whether to show the character count (when over 50% of limit)
    var shouldShowCharacterCount: Bool {
        let info = characterCountInfo
        return info.current > info.max / 2
    }

    /// Whether currently in cooldown
    var isInCooldown: Bool {
        safetyService.isInCooldown
    }

    // MARK: - Public Methods

    /// Sets the recipient for the message.
    func setRecipient(_ user: UserSearchResult) {
        recipient = user
    }

    /// Validates the body text and updates the validation error message.
    func validateBody() {
        let validation = safetyService.validate(content: bodyText)
        validationErrorMessage = validation.errorMessage
    }

    /// Sends the message.
    /// On success, state changes to .sent(topicId:) with the new thread's topic ID.
    func sendMessage() {
        guard canSend, let recipient = recipient else { return }

        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)

        state = .sending
        safetyService.willStartSend()

        Task {
            do {
                let topicId = try await discourseRepository.createPrivateMessage(
                    recipient: recipient.username,
                    title: trimmedSubject,
                    content: trimmedBody
                )

                // Update recent recipients on success
                recentRecipientsStorage.addRecipient(recipient.username)

                // Clear draft on successful send
                draftStorage.clearDraft()

                safetyService.didCompleteSend(success: true)
                state = .sent(topicId: topicId)
            } catch let error as DiscourseRepositoryError {
                safetyService.didCompleteSend(success: false)
                switch error {
                case .notAuthenticated:
                    state = .failed(message: "Nicht angemeldet")
                case .authenticationFailed(let message):
                    state = .failed(message: message)
                case .loadFailed(let message):
                    state = .failed(message: message)
                }
            } catch {
                safetyService.didCompleteSend(success: false)
                state = .failed(message: "Nachricht konnte nicht gesendet werden")
            }
        }
    }

    /// Resets the state after an error.
    func dismissError() {
        if case .failed = state {
            state = .idle
        }
    }

    /// Clears all content and any saved draft.
    func clearContent() {
        recipient = nil
        subject = ""
        bodyText = ""
        state = .idle
        validationErrorMessage = nil
        hasPendingDraft = false
        pendingDraft = nil
        draftStorage.clearDraft()
    }

    // MARK: - Draft Management

    /// Checks for a saved draft and updates hasPendingDraft.
    /// Call this when the compose screen appears.
    func checkForDraft() {
        if let draft = draftStorage.getDraft(), draft.hasContent {
            pendingDraft = draft
            hasPendingDraft = true
        } else {
            pendingDraft = nil
            hasPendingDraft = false
        }
    }

    /// Restores content from the pending draft.
    /// Call this when the user accepts the restore prompt.
    func restoreFromDraft() {
        guard let draft = pendingDraft else { return }

        // Restore recipient
        recipient = UserSearchResult(
            username: draft.recipientUsername,
            displayName: draft.recipientDisplayName,
            avatarUrl: nil
        )

        // Restore content
        subject = draft.subject
        bodyText = draft.body

        // Clear draft state
        hasPendingDraft = false
        pendingDraft = nil
        draftStorage.clearDraft()
    }

    /// Discards the pending draft without restoring.
    /// Call this when the user declines the restore prompt.
    func discardDraft() {
        hasPendingDraft = false
        pendingDraft = nil
        draftStorage.clearDraft()
    }

    /// Saves the current content as a draft.
    /// Call this when the compose screen disappears (if not sent).
    func saveDraft() {
        // Don't save if message was sent or if there's no content
        if case .sent = state { return }
        guard let recipient = recipient, hasContent else {
            // If no meaningful content, clear any existing draft
            draftStorage.clearDraft()
            return
        }

        let draft = MessageDraft(
            recipientUsername: recipient.username,
            recipientDisplayName: recipient.displayName,
            subject: subject,
            body: bodyText,
            savedAt: Date()
        )

        draftStorage.saveDraft(draft)
    }
}
