//
//  ForumViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation
import Combine

/// ViewModel for the Forum tab.
/// Coordinates between the ForumView and the DiscourseRepository.
/// Provides published state for SwiftUI data binding.
@MainActor
final class ForumViewModel: ObservableObject {

    // MARK: - Published State

    /// The list of topics to display
    @Published private(set) var topics: [Topic] = []

    /// Whether topics are currently being loaded
    @Published private(set) var isLoading: Bool = false

    /// Error message if loading failed, nil otherwise
    @Published private(set) var errorMessage: String?

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
        isLoading = true
        errorMessage = nil

        Task {
            let fetchedTopics = await discourseRepository.fetchTopics()
            self.topics = fetchedTopics
            self.isLoading = false
        }
    }

    /// Refreshes the topic list. Alias for loadTopics for pull-to-refresh.
    func refresh() {
        loadTopics()
    }
}
