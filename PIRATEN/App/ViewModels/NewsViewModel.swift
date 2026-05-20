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

    /// The last-seen message ID, used to determine which items are unread
    @Published private(set) var lastSeenMessageId: Int64 = 0

    private static let lastSeenNewsKey = "news_last_seen_message_id"

    // MARK: - Dependencies

    private let newsRepository: NewsRepository
    private let cache: NewsCacheStore
    private let stalenessGuard = StalenessGuard(minInterval: 600)

    // MARK: - Initialization

    init(newsRepository: NewsRepository, cache: NewsCacheStore) {
        self.newsRepository = newsRepository
        self.cache = cache
        self.lastSeenMessageId = Int64(UserDefaults.standard.integer(forKey: Self.lastSeenNewsKey))
    }

    // MARK: - Public Methods

    /// Loads news items with cache-first strategy.
    /// Shows cached items immediately, then fetches from network if the
    /// StalenessGuard says the cached data has aged out.
    func loadNews() {
        let cached = cache.cachedItems()
        if !cached.isEmpty {
            items = cached
            loadState = .loaded
        }

        guard stalenessGuard.isStale else { return }

        if items.isEmpty {
            loadState = .loading
        }

        Task {
            do {
                let fetched = try await newsRepository.fetchNews()
                #if DEBUG
                // TEMPORARY diagnostic for #67 follow-up — the `displayText`
                // strip is not catching all `<username>` prefixes. Dump the
                // raw text of the 3 most recent items so we can see the
                // exact shape and fix the strip logic. To be reverted once
                // the strip handles all known shapes.
                for item in fetched.prefix(3) {
                    print("[NEWS-RAW] messageId=\(item.messageId)")
                    print("[NEWS-RAW] text=⟨\(item.text)⟩")
                    print("[NEWS-RAW] displayText=⟨\(item.displayText)⟩")
                    print("[NEWS-RAW] headline=⟨\(item.headline)⟩")
                    print("[NEWS-RAW] ---")
                }
                #endif
                self.items = fetched
                self.loadState = .loaded
                self.errorMessage = nil
                self.updateNewContentFlag()
                self.stalenessGuard.markFetched()
            } catch {
                if self.items.isEmpty {
                    self.loadState = .error(message: "News konnten nicht geladen werden. Bitte überprüfe deine Verbindung.")
                } else {
                    self.errorMessage = "Aktualisierung fehlgeschlagen. Zeige zwischengespeicherte News."
                }
            }
        }
    }

    /// Pull-to-refresh: bypasses the StalenessGuard and always fetches fresh news.
    func refresh() {
        stalenessGuard.invalidate()
        loadNews()
    }

    /// Marks the News tab as viewed, clearing the new content indicator.
    func markAsViewed() {
        guard let newestId = items.first?.messageId else { return }
        UserDefaults.standard.set(newestId, forKey: Self.lastSeenNewsKey)
        lastSeenMessageId = newestId
        hasNewContent = false
    }

    /// Returns true if the given news item is newer than the last-seen threshold.
    func isNew(_ item: NewsItem) -> Bool {
        lastSeenMessageId != 0 && item.messageId > lastSeenMessageId
    }

    // MARK: - Private Helpers

    private func updateNewContentFlag() {
        guard let newestId = items.first?.messageId else { return }
        let lastSeen = Int64(UserDefaults.standard.integer(forKey: Self.lastSeenNewsKey))
        hasNewContent = lastSeen != 0 && newestId != lastSeen
    }
}
