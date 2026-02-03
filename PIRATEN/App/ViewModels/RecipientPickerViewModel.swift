//
//  RecipientPickerViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 02.02.26.
//

import Foundation
import Combine

/// ViewModel for the recipient picker screen.
/// Handles user search with debouncing and recent recipients display.
@MainActor
final class RecipientPickerViewModel: ObservableObject {

    // MARK: - Published State

    /// Current search query text
    @Published var searchText: String = ""

    /// Search results from the API
    @Published private(set) var searchResults: [UserSearchResult] = []

    /// Recent recipients from storage
    @Published private(set) var recentRecipients: [UserSearchResult] = []

    /// Whether a search is in progress
    @Published private(set) var isSearching: Bool = false

    /// Error message if search fails
    @Published private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let discourseRepository: DiscourseRepository
    private let recentRecipientsStorage: RecentRecipientsStorage

    // MARK: - Debounce

    private var searchTask: Task<Void, Never>?
    private static let debounceDelay: UInt64 = 300_000_000 // 300ms in nanoseconds

    // MARK: - Initialization

    init(
        discourseRepository: DiscourseRepository,
        recentRecipientsStorage: RecentRecipientsStorage
    ) {
        self.discourseRepository = discourseRepository
        self.recentRecipientsStorage = recentRecipientsStorage
    }

    // MARK: - Public Methods

    /// Loads recent recipients from storage.
    /// Call this when the view appears.
    func loadRecentRecipients() {
        let usernames = recentRecipientsStorage.getRecentRecipients()
        // Convert usernames to UserSearchResult (without avatar for now)
        // Limited to 5 for UI display
        recentRecipients = Array(usernames.prefix(5)).map { username in
            UserSearchResult(username: username, displayName: nil, avatarUrl: nil)
        }
    }

    /// Performs a debounced search for users.
    /// Call this when searchText changes.
    func performSearch() {
        // Cancel any pending search
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Clear results if query is too short
        guard query.count >= 2 else {
            searchResults = []
            isSearching = false
            errorMessage = nil
            return
        }

        isSearching = true
        errorMessage = nil

        // Debounce the search
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: Self.debounceDelay)

                // Check if cancelled during sleep
                guard !Task.isCancelled else { return }

                let results = try await discourseRepository.searchUsers(query: query)

                // Check if cancelled after API call
                guard !Task.isCancelled else { return }

                searchResults = results
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }

                if case DiscourseRepositoryError.loadFailed(let message) = error {
                    errorMessage = message
                } else {
                    errorMessage = "Suche fehlgeschlagen"
                }
                searchResults = []
                isSearching = false
            }
        }
    }

    /// Clears the current search.
    func clearSearch() {
        searchTask?.cancel()
        searchText = ""
        searchResults = []
        isSearching = false
        errorMessage = nil
    }
}
