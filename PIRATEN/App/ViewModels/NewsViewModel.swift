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
/// Manages fetching and displaying news items with cache-first loading.
@MainActor
final class NewsViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var items: [NewsItem] = []
    @Published private(set) var loadState: NewsLoadState = .idle
    @Published var errorMessage: String?

    /// Whether there are new news items since the user last viewed the News tab
    @Published private(set) var hasNewContent: Bool = false

    private static let lastSeenNewsKey = "news_last_seen_message_id"

    // MARK: - Dependencies

    private let newsRepository: NewsRepository
    private let cache: NewsCacheStore

    /// Timer for periodic background polling (every 3 minutes)
    private var pollingTimer: Timer?

    /// Polling interval in seconds (3 minutes)
    private static let pollingInterval: TimeInterval = 180

    // MARK: - Initialization

    init(newsRepository: NewsRepository, cache: NewsCacheStore) {
        self.newsRepository = newsRepository
        self.cache = cache
        startPolling()
    }

    deinit {
        pollingTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Loads news items with cache-first strategy.
    /// Shows cached items immediately, then fetches from network.
    func loadNews() {
        // Show cached items immediately
        let cached = cache.cachedItems()
        if !cached.isEmpty {
            items = cached
            loadState = .loaded
        } else {
            loadState = .loading
        }

        Task {
            do {
                let fetched = try await newsRepository.fetchNews()
                self.items = fetched
                self.loadState = .loaded
                self.errorMessage = nil
                self.updateNewContentFlag()
            } catch {
                if self.items.isEmpty {
                    self.loadState = .error(message: "News konnten nicht geladen werden. Bitte überprüfe deine Verbindung.")
                } else {
                    self.errorMessage = "Aktualisierung fehlgeschlagen. Zeige zwischengespeicherte News."
                }
            }
        }
    }

    /// Refreshes the news feed from the network.
    func refresh() {
        Task {
            do {
                let fetched = try await newsRepository.fetchNews()
                self.items = fetched
                self.loadState = .loaded
                self.errorMessage = nil
                self.updateNewContentFlag()
            } catch {
                if self.items.isEmpty {
                    self.loadState = .error(message: "News konnten nicht geladen werden. Bitte überprüfe deine Verbindung.")
                } else {
                    self.errorMessage = "Aktualisierung fehlgeschlagen."
                }
            }
        }
    }

    /// Marks the News tab as viewed, clearing the new content indicator.
    func markAsViewed() {
        guard let newestId = items.first?.messageId else { return }
        UserDefaults.standard.set(newestId, forKey: Self.lastSeenNewsKey)
        hasNewContent = false
    }

    // MARK: - Private Helpers

    /// Starts a repeating timer that polls for new news content every 3 minutes.
    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: Self.pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollForNewContent()
            }
        }
    }

    /// Fetches news in the background and updates the new-content badge
    /// without disrupting the current view.
    private func pollForNewContent() async {
        do {
            let fetched = try await newsRepository.fetchNews()
            if items.isEmpty {
                items = fetched
                loadState = .loaded
            }
            guard let newestId = fetched.first?.messageId else { return }
            let lastSeen = Int64(UserDefaults.standard.integer(forKey: Self.lastSeenNewsKey))
            hasNewContent = lastSeen != 0 && newestId != lastSeen
        } catch {
            // Polling failures are silent
        }
    }

    private func updateNewContentFlag() {
        guard let newestId = items.first?.messageId else { return }
        let lastSeen = Int64(UserDefaults.standard.integer(forKey: Self.lastSeenNewsKey))
        hasNewContent = lastSeen != 0 && newestId != lastSeen
    }
}
