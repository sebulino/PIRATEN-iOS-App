//
//  TopicDetailViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation
import Combine

/// Represents the current state of the topic detail view.
enum TopicDetailLoadState: Equatable {
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

/// ViewModel for the topic detail screen.
/// Coordinates between the TopicDetailView and the DiscourseRepository.
@MainActor
final class TopicDetailViewModel: ObservableObject {

    // MARK: - Published State

    /// The topic being viewed
    @Published private(set) var topic: Topic

    /// The list of posts in this topic
    @Published private(set) var posts: [Post] = []

    /// The current load state
    @Published private(set) var loadState: TopicDetailLoadState = .idle

    // MARK: - Dependencies

    private let discourseRepository: DiscourseRepository

    // MARK: - Initialization

    /// Creates a TopicDetailViewModel with the given topic and repository.
    /// - Parameters:
    ///   - topic: The topic to display details for
    ///   - discourseRepository: The repository to fetch post data from
    init(topic: Topic, discourseRepository: DiscourseRepository) {
        self.topic = topic
        self.discourseRepository = discourseRepository
    }

    // MARK: - Public Methods

    /// Loads posts for the current topic.
    func loadPosts() {
        loadState = .loading

        Task {
            do {
                let fetchedPosts = try await discourseRepository.fetchPosts(forTopicId: topic.id)
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
