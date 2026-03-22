//
//  KnowledgeViewModel.swift
//  PIRATEN
//

import Combine
import Foundation

/// Load state for the Knowledge Hub home screen.
enum KnowledgeLoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(message: String)
}

/// ViewModel for the Knowledge Hub home screen.
/// Manages index loading, search filtering, and reading progress integration.
@MainActor
final class KnowledgeViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var loadState: KnowledgeLoadState = .idle
    @Published private(set) var index: KnowledgeIndex?
    @Published var searchQuery: String = ""
    @Published private(set) var hasNewContent: Bool = false

    private static let lastSeenTopicIdKey = "knowledge_lastSeenTopicId"

    // MARK: - Dependencies

    private let repository: KnowledgeRepository
    private let progressStore: ReadingProgressStorage

    // MARK: - Initialization

    init(repository: KnowledgeRepository, progressStore: ReadingProgressStorage) {
        self.repository = repository
        self.progressStore = progressStore
    }

    // MARK: - Computed Properties

    /// All categories from the loaded index, sorted by order.
    var categories: [KnowledgeCategory] {
        index?.categories ?? []
    }

    /// Topics marked as featured in kanon.json.
    var featuredTopics: [KnowledgeTopic] {
        guard let index else { return [] }
        return index.featuredTopicIds.compactMap { featuredId in
            index.topics.first { $0.id == featuredId }
        }
    }

    /// Topics the user has started but not completed.
    var inProgressTopics: [KnowledgeTopic] {
        guard let index else { return [] }
        let allProgress = progressStore.getAllProgress()
        return allProgress.values
            .filter { $0.status == .started }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            .compactMap { progress in
                index.topics.first { $0.id == progress.topicId }
            }
    }

    /// Search results filtered by query on title + summary + tags (case-insensitive).
    /// Returns nil when no search is active, empty array when search has no matches.
    var searchResults: [KnowledgeTopic]? {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard let index else { return [] }

        let query = trimmed.lowercased()
        return index.topics.filter { topic in
            topic.title.lowercased().contains(query)
                || topic.summary.lowercased().contains(query)
                || topic.tags.contains { $0.lowercased().contains(query) }
        }
    }

    // MARK: - Public Methods

    /// Loads the knowledge index. Uses cache unless forceRefresh is true.
    func loadIndex(forceRefresh: Bool = false) {
        loadState = .loading
        Task {
            do {
                let fetchedIndex = try await repository.fetchIndex(forceRefresh: forceRefresh)
                self.index = fetchedIndex
                self.loadState = .loaded
                self.updateNewContentFlag()
            } catch let error as KnowledgeError {
                self.loadState = .error(message: error.localizedDescription)
            } catch {
                self.loadState = .error(message: "Ein unbekannter Fehler ist aufgetreten")
            }
        }
    }

    /// Returns all topics belonging to a given category.
    func topicsForCategory(_ categoryId: String) -> [KnowledgeTopic] {
        guard let index else { return [] }
        return index.topics.filter { $0.categoryId == categoryId }
    }

    /// Returns the reading progress for a specific topic.
    func progress(for topicId: String) -> TopicProgress? {
        progressStore.getProgress(for: topicId)
    }

    /// Marks the Knowledge tab as viewed, clearing the new content indicator.
    func markAsViewed() {
        guard let newestId = index?.topics.first?.id else { return }
        UserDefaults.standard.set(newestId, forKey: Self.lastSeenTopicIdKey)
        hasNewContent = false
    }

    // MARK: - Private Helpers

    private func updateNewContentFlag() {
        guard let newestId = index?.topics.first?.id else { return }
        let lastSeen = UserDefaults.standard.string(forKey: Self.lastSeenTopicIdKey)
        hasNewContent = lastSeen != nil && newestId != lastSeen
    }
}
