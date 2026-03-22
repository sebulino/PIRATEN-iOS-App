//
//  MessagesViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation
import Combine

/// Represents the current state of the messages view.
enum MessagesLoadState: Equatable {
    /// Initial state, no data loaded yet
    case idle

    /// Currently loading message threads
    case loading

    /// Message threads loaded successfully (may be empty)
    case loaded

    /// User is not authenticated - should show login prompt
    case notAuthenticated

    /// Authentication failed (session expired) - should show re-login prompt
    case authenticationFailed(message: String)

    /// Loading failed with an error message
    case error(message: String)
}

/// ViewModel for the Messages tab.
/// Coordinates between the MessagesView and the DiscourseRepository.
/// Provides published state for SwiftUI data binding.
@MainActor
final class MessagesViewModel: ObservableObject {

    // MARK: - Published State

    /// The list of message threads to display
    @Published private(set) var messageThreads: [MessageThread] = []

    /// The current load state of the messages
    @Published private(set) var loadState: MessagesLoadState = .idle

    /// Whether there are unread message threads
    var hasNewContent: Bool {
        messageThreads.contains { !$0.isRead }
    }

    /// Convenience property for backward compatibility
    var isLoading: Bool {
        loadState == .loading
    }

    /// Convenience property for backward compatibility
    var errorMessage: String? {
        switch loadState {
        case .error(let message), .authenticationFailed(let message):
            return message
        default:
            return nil
        }
    }

    // MARK: - Dependencies

    private let discourseRepository: DiscourseRepository
    private let authRepository: AuthRepository

    // MARK: - Initialization

    /// Creates a MessagesViewModel with the given repositories.
    /// - Parameters:
    ///   - discourseRepository: The repository to fetch message data from
    ///   - authRepository: The repository to get current user information from
    init(discourseRepository: DiscourseRepository, authRepository: AuthRepository) {
        self.discourseRepository = discourseRepository
        self.authRepository = authRepository
    }

    // MARK: - Public Methods

    /// Loads the list of message threads from the repository.
    /// Updates published state for loading, threads, and errors.
    func loadMessages() {
        loadState = .loading

        Task {
            // First, get the current user's username
            guard let currentUser = await authRepository.getCurrentUser() else {
                self.loadState = .notAuthenticated
                return
            }

            do {
                let fetchedThreads = try await discourseRepository.fetchMessageThreads(
                    for: currentUser.username
                )
                self.messageThreads = fetchedThreads
                self.loadState = .loaded
            } catch let error as DiscourseRepositoryError {
                handleError(error)
            } catch {
                self.loadState = .error(message: "Ein unbekannter Fehler ist aufgetreten")
            }
        }
    }

    /// Refreshes the message thread list.
    func refresh() {
        loadMessages()
    }

    /// Updates the local thread list to mark a thread as read (no network call).
    /// Called when the user views a message thread detail, so the list background updates immediately.
    func markThreadAsRead(id: Int) {
        guard let index = messageThreads.firstIndex(where: { $0.id == id }) else { return }
        let t = messageThreads[index]
        guard !t.isRead else { return }
        messageThreads[index] = MessageThread(
            id: t.id,
            title: t.title,
            participants: t.participants,
            createdAt: t.createdAt,
            lastActivityAt: t.lastActivityAt,
            postsCount: t.postsCount,
            isRead: true,
            lastPoster: t.lastPoster
        )
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
