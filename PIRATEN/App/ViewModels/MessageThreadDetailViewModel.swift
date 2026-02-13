//
//  MessageThreadDetailViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 01.02.26.
//

import Foundation
import Combine

/// Represents the current state of the message thread detail view.
enum MessageThreadDetailLoadState: Equatable {
    /// Initial state, no data loaded yet
    case idle

    /// Currently loading posts
    case loading

    /// Posts loaded successfully
    case loaded

    /// User is not authenticated - should show login prompt
    case notAuthenticated

    /// Authentication failed (session expired) - should show re-login prompt
    case authenticationFailed(message: String)

    /// Loading failed with an error message
    case error(message: String)
}

/// Represents the state of the reply composer.
enum ReplyComposerState: Equatable {
    /// Composer is ready for input
    case idle

    /// Reply is being sent
    case sending

    /// Reply was sent successfully
    case sent

    /// Sending failed with an error message
    case failed(message: String)
}

/// ViewModel for the message thread detail screen.
/// Coordinates between the MessageThreadDetailView and the DiscourseRepository.
///
/// Note: Private messages in Discourse are stored as topics with archetype='private_message'.
/// The same /t/{id}.json endpoint is used to fetch posts for both regular topics and PMs.
///
/// Privacy consideration: This view model intentionally does NOT log any content,
/// participant names, or thread identifiers. Debug logging only outputs sanitized state info.
@MainActor
final class MessageThreadDetailViewModel: ObservableObject {

    // MARK: - Constants

    /// UserDefaults key for tracking whether the reply hint has been dismissed
    private static let replyHintDismissedKey = "messageThreadReplyHintDismissed"

    // MARK: - Published State

    /// The message thread being viewed
    @Published private(set) var thread: MessageThread

    /// The list of posts/messages in this thread
    @Published private(set) var posts: [Post] = []

    /// The current load state
    @Published private(set) var loadState: MessageThreadDetailLoadState = .idle

    /// Whether the reply composer is currently shown
    @Published var isComposerVisible: Bool = false

    /// The text content of the reply being composed
    @Published var replyText: String = ""

    /// The current state of the reply composer
    @Published private(set) var composerState: ReplyComposerState = .idle

    /// Validation error message for the composer (nil if valid)
    @Published private(set) var validationErrorMessage: String?

    /// Whether to show the one-time reply hint to help users discover the reply button
    @Published var shouldShowReplyHint: Bool

    /// Whether the user is authenticated (determined from load state)
    var isAuthenticated: Bool {
        switch loadState {
        case .notAuthenticated, .authenticationFailed:
            return false
        default:
            return true
        }
    }

    /// Whether the send button should be enabled
    /// Checks message validity, rate limits, and sending state
    var canSendReply: Bool {
        let validation = safetyService.validate(content: replyText)
        return validation.isValid
            && composerState != .sending
            && safetyService.canSend()
    }

    /// Current character count info for display
    var characterCountInfo: (current: Int, max: Int, isOverLimit: Bool) {
        safetyService.characterCount(for: replyText)
    }

    /// Whether currently in cooldown after sending
    var isInCooldown: Bool {
        safetyService.isInCooldown
    }

    // MARK: - Dependencies

    private let discourseRepository: DiscourseRepository
    private let safetyService: MessageSafetyService

    // MARK: - Initialization

    /// Creates a MessageThreadDetailViewModel with the given thread and repository.
    /// - Parameters:
    ///   - thread: The message thread to display details for
    ///   - discourseRepository: The repository to fetch post data from
    ///   - safetyService: The safety service for rate limiting and validation (optional, creates new instance if nil)
    init(
        thread: MessageThread,
        discourseRepository: DiscourseRepository,
        safetyService: MessageSafetyService? = nil
    ) {
        self.thread = thread
        self.discourseRepository = discourseRepository
        self.safetyService = safetyService ?? MessageSafetyService()

        // Load hint dismissed state from UserDefaults
        // If not dismissed yet, show the hint to help users discover the reply feature
        self.shouldShowReplyHint = !UserDefaults.standard.bool(forKey: Self.replyHintDismissedKey)
    }

    // MARK: - Public Methods

    /// Loads posts for the current message thread.
    /// Uses the same fetchPosts endpoint as regular topics since Discourse
    /// stores PMs as topics with archetype='private_message'.
    func loadPosts() {
        loadState = .loading

        Task {
            do {
                // PM threads use the same topic ID system as regular topics
                // The /t/{id}.json endpoint works for both
                let fetchedPosts = try await discourseRepository.fetchPosts(forTopicId: thread.id)
                self.posts = fetchedPosts
                self.loadState = .loaded
            } catch let error as DiscourseRepositoryError {
                handleError(error)
            } catch {
                self.loadState = .error(message: "Ein unbekannter Fehler ist aufgetreten")
            }
        }
    }

    /// Retries loading posts after an error.
    func retry() {
        loadPosts()
    }

    // MARK: - Reply Composer Methods

    /// Shows the reply composer and dismisses the hint (since user discovered the feature).
    func showComposer() {
        isComposerVisible = true
        composerState = .idle
        dismissReplyHint()
    }

    /// Dismisses the reply hint and persists this choice.
    /// Once dismissed, the hint will not be shown again.
    func dismissReplyHint() {
        shouldShowReplyHint = false
        UserDefaults.standard.set(true, forKey: Self.replyHintDismissedKey)
    }

    /// Hides the reply composer and clears the text.
    func hideComposer() {
        isComposerVisible = false
        replyText = ""
        composerState = .idle
        validationErrorMessage = nil
    }

    /// Validates the current reply text and updates the validation error message.
    /// Call this when the user changes the text to provide real-time feedback.
    func validateReplyText() {
        let validation = safetyService.validate(content: replyText)
        validationErrorMessage = validation.errorMessage
    }

    /// Sends the reply via the Discourse API.
    /// Uses DiscourseRepository.replyToThread to POST the message.
    /// Respects rate limiting via MessageSafetyService.
    func sendReply() {
        // Validate before sending
        let validation = safetyService.validate(content: replyText)
        guard validation.isValid else {
            validationErrorMessage = validation.errorMessage
            return
        }

        // Check rate limit
        guard safetyService.canSend() else {
            composerState = .failed(message: "Bitte warte einen Moment vor dem nächsten Senden.")
            return
        }

        let contentToSend = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        composerState = .sending
        safetyService.willStartSend()

        Task {
            do {
                // Send the reply via API
                try await discourseRepository.replyToThread(
                    topicId: thread.id,
                    content: contentToSend
                )

                // Mark as sent successfully
                safetyService.didCompleteSend(success: true)
                composerState = .sent
                replyText = ""
                validationErrorMessage = nil

                // After a brief moment, hide composer and reload posts
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                isComposerVisible = false
                composerState = .idle

                // Reload posts to show the new message
                loadPosts()
            } catch let error as DiscourseRepositoryError {
                safetyService.didCompleteSend(success: false)
                handleComposerError(error)
            } catch {
                safetyService.didCompleteSend(success: false)
                composerState = .failed(message: "Nachricht konnte nicht gesendet werden")
            }
        }
    }

    // MARK: - Private Helpers (Composer)

    private func handleComposerError(_ error: DiscourseRepositoryError) {
        switch error {
        case .notAuthenticated:
            loadState = .notAuthenticated
            composerState = .idle
        case .authenticationFailed(let message):
            loadState = .authenticationFailed(message: message)
            composerState = .idle
        case .loadFailed(let message):
            composerState = .failed(message: message)
        }
    }

    /// Dismisses any error state in the composer.
    func dismissComposerError() {
        if case .failed = composerState {
            composerState = .idle
        }
    }

    // MARK: - Private Helpers

    private func handleError(_ error: DiscourseRepositoryError) {
        switch error {
        case .notAuthenticated:
            loadState = .notAuthenticated
        case .authenticationFailed(let message):
            loadState = .authenticationFailed(message: message)
        case .loadFailed(let message):
            loadState = .error(message: message)
        }
    }
}
