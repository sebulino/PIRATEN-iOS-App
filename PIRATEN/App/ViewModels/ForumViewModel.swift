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

    // MARK: - Initialization

    /// Creates a ForumViewModel with the given repository.
    /// - Parameter discourseRepository: The repository to fetch forum data from
    init(discourseRepository: DiscourseRepository) {
        self.discourseRepository = discourseRepository
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
