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

    /// Timer for periodic background polling (every 30 minutes)
    private var pollingTimer: Timer?

    /// Polling interval in seconds (60 seconds)
    private static let pollingInterval: TimeInterval = 60

    // MARK: - Initialization

    /// Creates a ForumViewModel with the given repository.
    /// - Parameter discourseRepository: The repository to fetch forum data from
    init(discourseRepository: DiscourseRepository) {
        self.discourseRepository = discourseRepository
        startPolling()
    }

    deinit {
        pollingTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Loads the list of topics from the repository.
    /// Updates published state for loading, topics, and errors.
    func loadTopics() {
        loadState = .loading

        Task {
            do {
                let fetchedTopics = try await discourseRepository.fetchTopics()
                self.topics = fetchedTopics
                self.loadState = .loaded
                self.updateNewContentFlag()
            } catch let error as DiscourseRepositoryError {
                handleError(error)
            } catch {
                self.loadState = .error(message: "Ein unbekannter Fehler ist aufgetreten")
            }
        }
    }

    /// Refreshes the topic list.
    func refresh() {
        loadTopics()
    }

    /// Updates the local topic list to mark a topic as read (no network call).
    /// Called when the user views a topic detail, so the list background updates immediately.
    func markTopicAsRead(id: Int) {
        guard let index = topics.firstIndex(where: { $0.id == id }) else { return }
        let t = topics[index]
        guard !t.isRead else { return }
        topics[index] = Topic(
            id: t.id,
            title: t.title,
            createdBy: t.createdBy,
            createdAt: t.createdAt,
            postsCount: t.postsCount,
            viewCount: t.viewCount,
            likeCount: t.likeCount,
            categoryId: t.categoryId,
            isVisible: t.isVisible,
            isClosed: t.isClosed,
            isArchived: t.isArchived,
            isRead: true
        )
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

    /// Starts a repeating timer that polls for new forum content every 30 minutes.
    /// Only updates the new-content flag without replacing the visible topic list,
    /// so the user isn't disrupted while browsing.
    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: Self.pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollForNewContent()
            }
        }
    }

    /// Fetches topics in the background and updates the new-content badge
    /// without replacing the visible topic list.
    private func pollForNewContent() async {
        do {
            let fetchedTopics = try await discourseRepository.fetchTopics()
            // Only update the badge flag; don't replace the displayed list
            // unless the user hasn't loaded anything yet
            if topics.isEmpty {
                topics = fetchedTopics
                loadState = .loaded
            }
            // Check if there's new content by comparing newest topic ID
            guard let newestId = fetchedTopics.first?.id else { return }
            let lastSeen = UserDefaults.standard.integer(forKey: Self.lastSeenTopicKey)
            hasNewContent = lastSeen != 0 && newestId != lastSeen
        } catch {
            // Polling failures are silent — don't disturb the user
        }
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
