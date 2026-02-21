//
//  HomeViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 19.02.26.
//

import Foundation
import Combine

/// Represents the current state of the home dashboard.
enum HomeLoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(message: String)
}

/// ViewModel for the Kajüte (Home) tab.
/// Aggregates data from multiple repositories for the dashboard view.
/// Each section loads independently — partial data is acceptable.
@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var loadState: HomeLoadState = .idle

    /// Recent contacts extracted from message thread participants
    @Published private(set) var recentContacts: [UserSummary] = []

    /// Knowledge articles to continue reading or discover
    @Published private(set) var knowledgeArticles: [KnowledgeTopic] = []

    /// Recent forum topics
    @Published private(set) var recentTopics: [Topic] = []

    // MARK: - Dependencies

    private let discourseRepository: DiscourseRepository
    private let knowledgeRepository: KnowledgeRepository
    private let readingProgressStorage: ReadingProgressStorage
    private let authRepository: AuthRepository

    // MARK: - Initialization

    init(
        discourseRepository: DiscourseRepository,
        knowledgeRepository: KnowledgeRepository,
        readingProgressStorage: ReadingProgressStorage,
        authRepository: AuthRepository
    ) {
        self.discourseRepository = discourseRepository
        self.knowledgeRepository = knowledgeRepository
        self.readingProgressStorage = readingProgressStorage
        self.authRepository = authRepository
    }

    // MARK: - Public Methods

    /// Loads all dashboard sections concurrently.
    /// Each section fails independently — partial data is shown.
    func loadDashboard() {
        loadState = .loading

        Task {
            async let contactsResult = loadRecentContacts()
            async let articlesResult = loadKnowledgeArticles()
            async let topicsResult = loadRecentTopics()

            let contacts = await contactsResult
            let articles = await articlesResult
            let topics = await topicsResult

            self.recentContacts = contacts
            self.knowledgeArticles = articles
            self.recentTopics = topics
            self.loadState = .loaded
        }
    }

    /// Refreshes all dashboard data.
    func refresh() {
        loadDashboard()
    }

    // MARK: - Private Section Loaders

    /// Loads recent contacts from message threads.
    /// Extracts unique participants from the most recent threads.
    private func loadRecentContacts() async -> [UserSummary] {
        guard let currentUser = await authRepository.getCurrentUser() else {
            return []
        }

        do {
            let threads = try await discourseRepository.fetchMessageThreads(for: currentUser.username)
            var seen = Set<Int>()
            var contacts: [UserSummary] = []

            for thread in threads {
                for participant in thread.participants {
                    // Skip self and duplicates
                    if participant.username != currentUser.username && !seen.contains(participant.id) {
                        seen.insert(participant.id)
                        contacts.append(participant)
                    }
                }
                if contacts.count >= 10 { break }
            }

            return contacts
        } catch {
            return []
        }
    }

    /// Loads knowledge articles: in-progress topics first, then fill with unread.
    /// Returns up to 3 articles.
    private func loadKnowledgeArticles() async -> [KnowledgeTopic] {
        do {
            let index = try await knowledgeRepository.fetchIndex(forceRefresh: false)
            let allProgress = readingProgressStorage.getAllProgress()

            // Get in-progress topics
            var articles = allProgress.values
                .filter { $0.status == .started }
                .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
                .prefix(3)
                .compactMap { progress in
                    index.topics.first { $0.id == progress.topicId }
                }

            // Fill remaining slots with unread topics
            if articles.count < 3 {
                let startedOrCompletedIds = Set(allProgress.values.map(\.topicId))
                let unread = index.topics.filter { !startedOrCompletedIds.contains($0.id) }
                let remaining = 3 - articles.count
                articles.append(contentsOf: unread.prefix(remaining))
            }

            return Array(articles.prefix(3))
        } catch {
            return []
        }
    }

    /// Loads the most recent forum topics.
    private func loadRecentTopics() async -> [Topic] {
        do {
            let topics = try await discourseRepository.fetchTopics()
            return Array(topics.prefix(5))
        } catch {
            return []
        }
    }
}
