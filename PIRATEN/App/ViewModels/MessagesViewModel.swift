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

    /// Whether there are unread message threads or new content detected via polling
    var hasNewContent: Bool {
        messageThreads.contains { !$0.isRead } || messageThreads.count != lastKnownMessageCount
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
    private let cache: DiscourseCacheStore
    private let stalenessGuard = StalenessGuard(minInterval: 120)

    /// Last known message count for detecting new content
    private var lastKnownMessageCount: Int = 0

    // MARK: - Initialization

    /// Creates a MessagesViewModel with the given repositories.
    /// - Parameters:
    ///   - discourseRepository: The repository to fetch message data from
    ///   - authRepository: The repository to get current user information from
    ///   - cache: Cache store for persisting message threads across app launches
    init(discourseRepository: DiscourseRepository, authRepository: AuthRepository, cache: DiscourseCacheStore = DiscourseCacheStore()) {
        self.discourseRepository = discourseRepository
        self.authRepository = authRepository
        self.cache = cache
    }

    // MARK: - Public Methods

    /// Loads the list of message threads from the repository.
    /// Uses cache-first strategy: shows cached threads immediately, then fetches fresh data
    /// if the StalenessGuard says the cached data has aged out.
    /// - Parameter includeSent: Whether to also fetch sent messages (Outbox). Default `true`.
    ///   Pass `false` for tab-switch loads to save one request.
    func loadMessages(includeSent: Bool = true) {
        let cached = cache.cachedMessageThreads()
        if !cached.isEmpty {
            messageThreads = cached
            lastKnownMessageCount = cached.count
            loadState = .loaded
        }

        guard stalenessGuard.isStale else { return }

        if messageThreads.isEmpty {
            loadState = .loading
        }

        Task {
            // First, get the current user's username
            guard let currentUser = await authRepository.getCurrentUser() else {
                self.loadState = .notAuthenticated
                return
            }

            do {
                let fetchedThreads = try await discourseRepository.fetchMessageThreads(
                    for: currentUser.username,
                    includeSent: includeSent
                )
                self.messageThreads = fetchedThreads
                self.lastKnownMessageCount = fetchedThreads.count
                self.loadState = .loaded
                self.cache.saveMessageThreads(fetchedThreads)
                self.stalenessGuard.markFetched()
            } catch let error as DiscourseRepositoryError {
                if self.messageThreads.isEmpty {
                    handleError(error)
                }
            } catch {
                if self.messageThreads.isEmpty {
                    self.loadState = .error(message: "Ein unbekannter Fehler ist aufgetreten")
                }
            }
        }
    }

    /// Pull-to-refresh: bypasses the StalenessGuard and always fetches fresh data,
    /// including the sent/outbox half of the mailbox.
    func refresh() {
        stalenessGuard.invalidate()
        loadMessages(includeSent: true)
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

    /// Archives a message thread on Discourse and removes it from the local list.
    func archiveThread(id: Int) {
        Task {
            do {
                try await discourseRepository.archiveMessageThread(topicId: id)
                messageThreads.removeAll { $0.id == id }
            } catch let error as DiscourseRepositoryError {
                handleError(error)
            } catch {
                loadState = .error(message: "Nachricht konnte nicht archiviert werden")
            }
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
