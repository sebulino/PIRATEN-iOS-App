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
/// Handles recipient, subject, body, and safety validation.
@MainActor
final class ComposeMessageViewModel: ObservableObject {

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

    // MARK: - Dependencies

    private let discourseRepository: DiscourseRepository
    private let safetyService: MessageSafetyService
    private let recentRecipientsStorage: RecentRecipientsStorage

    // MARK: - Initialization

    init(
        discourseRepository: DiscourseRepository,
        safetyService: MessageSafetyService? = nil,
        recentRecipientsStorage: RecentRecipientsStorage
    ) {
        self.discourseRepository = discourseRepository
        self.safetyService = safetyService ?? MessageSafetyService()
        self.recentRecipientsStorage = recentRecipientsStorage
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

    /// Clears all content.
    func clearContent() {
        recipient = nil
        subject = ""
        bodyText = ""
        state = .idle
        validationErrorMessage = nil
    }
}
