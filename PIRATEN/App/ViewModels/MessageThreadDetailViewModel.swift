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
