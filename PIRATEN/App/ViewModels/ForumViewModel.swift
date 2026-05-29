//
//  ForumViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation
import Combine

/// Represents the current state of the forum view.
enum ForumLoadState: Equatable {
    /// Initial state, no data loaded yet
    case idle

    /// Currently loading topics
    case loading

    /// Topics loaded successfully (may be empty)
    case loaded

    /// User is not authenticated - should show login prompt
    case notAuthenticated

    /// Authentication failed (session expired) - should show re-login prompt
    case authenticationFailed(message: String)

    /// Loading failed with an error message
    case error(message: String)
}

/// ViewModel for the Forum tab.
/// Coordinates between the ForumView and the DiscourseRepository.
/// Provides published state for SwiftUI data binding.
@MainActor
final class ForumViewModel: ObservableObject {

    // MARK: - Published State

    /// The list of topics to display
    @Published private(set) var topics: [Topic] = []

    /// The current load state of the forum
    @Published private(set) var loadState: ForumLoadState = .idle

    /// Whether there are new topics since the user last viewed the Forum tab
    @Published private(set) var hasNewContent: Bool = false

    private static let lastSeenTopicKey = "forum_last_seen_topic_id"

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
    private let cache: DiscourseCacheStore
    private let stalenessGuard = StalenessGuard(minInterval: 120)

    // MARK: - Initialization

    /// Creates a ForumViewModel with the given repository.
    /// - Parameters:
    ///   - discourseRepository: The repository to fetch forum data from
    ///   - cache: Cache store for persisting topics across app launches
    init(discourseRepository: DiscourseRepository, cache: DiscourseCacheStore = DiscourseCacheStore()) {
        self.discourseRepository = discourseRepository
        self.cache = cache
    }

    // MARK: - Public Methods

    /// Loads the list of topics from the repository.
    /// Uses cache-first strategy: shows cached topics immediately, then fetches fresh data
    /// — but only if the StalenessGuard says the cached data has aged out.
    func loadTopics() {
        let cached = cache.cachedTopics()
        if !cached.isEmpty {
            topics = cached
            loadState = .loaded
        }

        guard stalenessGuard.isStale else { return }

        if topics.isEmpty {
            loadState = .loading
        }

        Task {
            do {
                let fetchedTopics = try await discourseRepository.fetchTopics()
                self.topics = fetchedTopics
                self.loadState = .loaded
                self.updateNewContentFlag()
                self.cache.saveTopics(fetchedTopics)
                self.stalenessGuard.markFetched()
            } catch let error as DiscourseRepositoryError {
                if self.topics.isEmpty {
                    handleError(error)
                }
            } catch {
                if self.topics.isEmpty {
                    self.loadState = .error(message: "Ein unbekannter Fehler ist aufgetreten")
                }
            }
        }
    }

    /// Pull-to-refresh: bypasses the StalenessGuard and always fetches fresh data.
    func refresh() {
        stalenessGuard.invalidate()
        loadTopics()
    }

    /// Updates the local topic list to mark a topic as read (no network call).
    /// Called when the user views a topic detail, so the list background updates immediately.
    func markTopicAsRead(id: Int) {
        guard let index = topics.firstIndex(where: { $0.id == id }),
              !topics[index].isRead else { return }
        topics[index] = topics[index].markedRead()
        // Persist so the Kajüte's "Aktuelle Themen" (and any other cache reader)
        // reflects the read state too, not just this in-memory list.
        cache.saveTopics(topics)
    }

    // MARK: - Private Helpers

    /// Marks the Forum tab as viewed, clearing the new content indicator.
    func markAsViewed() {
        guard let firstId = topics.first?.id else { return }
        UserDefaults.standard.set(firstId, forKey: Self.lastSeenTopicKey)
        hasNewContent = false
    }

    private func updateNewContentFlag() {
        guard let newestId = topics.first?.id else { return }
        let lastSeen = UserDefaults.standard.integer(forKey: Self.lastSeenTopicKey)
        hasNewContent = lastSeen != 0 && newestId != lastSeen
    }

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
