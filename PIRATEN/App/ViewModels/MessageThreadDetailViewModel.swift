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
    var canSendReply: Bool {
        !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && composerState != .sending
    }

    // MARK: - Dependencies

    private let discourseRepository: DiscourseRepository

    // MARK: - Initialization

    /// Creates a MessageThreadDetailViewModel with the given thread and repository.
    /// - Parameters:
    ///   - thread: The message thread to display details for
    ///   - discourseRepository: The repository to fetch post data from
    init(thread: MessageThread, discourseRepository: DiscourseRepository) {
        self.thread = thread
        self.discourseRepository = discourseRepository
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

    /// Shows the reply composer.
    func showComposer() {
        isComposerVisible = true
        composerState = .idle
    }

    /// Hides the reply composer and clears the text.
    func hideComposer() {
        isComposerVisible = false
        replyText = ""
        composerState = .idle
    }

    /// Sends the reply. This is a UI-only stub for M4-001.
    /// The actual API call will be implemented in M4-002.
    func sendReply() {
        guard canSendReply else { return }

        composerState = .sending

        // M4-001: Stub implementation - actual API call in M4-002
        // For now, we simulate a successful send for UI testing
        Task {
            // Simulate network delay (to be replaced with actual API call)
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Mark as sent and clear the composer
            composerState = .sent
            replyText = ""

            // After a brief moment, hide composer and reload posts
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            isComposerVisible = false
            composerState = .idle

            // Reload posts to show the new message (will be real data once M4-002 is done)
            loadPosts()
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
