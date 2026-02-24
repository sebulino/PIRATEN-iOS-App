//
//  NewsViewModel.swift
//  PIRATEN
//

import Combine
import Foundation

/// Load state for the News tab.
enum NewsLoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(message: String)
}

/// ViewModel for the News tab.
/// Manages fetching and displaying Telegram bot news posts.
@MainActor
final class NewsViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var posts: [NewsPost] = []
    @Published private(set) var loadState: NewsLoadState = .idle

    // MARK: - Dependencies

    private let newsRepository: NewsRepository

    // MARK: - Initialization

    init(newsRepository: NewsRepository) {
        self.newsRepository = newsRepository
    }

    // MARK: - Public Methods

    /// Loads news posts from the repository.
    func loadNews() {
        loadState = .loading

        Task {
            do {
                let fetchedPosts = try await newsRepository.fetchNews()
                self.posts = fetchedPosts
                self.loadState = .loaded
            } catch {
                self.loadState = .error(message: "News konnten nicht geladen werden. Bitte überprüfe deine Verbindung.")
            }
        }
    }

    /// Refreshes the news feed. Alias for pull-to-refresh.
    func refresh() {
        loadNews()
    }
}
