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

    /// First name of the current user for the greeting
    @Published private(set) var userFirstName: String?

    /// Recent contacts extracted from message thread participants
    @Published private(set) var recentContacts: [UserSummary] = []

    /// Number of unread private message threads
    @Published private(set) var unreadMessageCount: Int = 0


    /// Knowledge articles to continue reading or discover
    @Published private(set) var knowledgeArticles: [KnowledgeTopic] = []

    /// Recent forum topics
    @Published private(set) var recentTopics: [Topic] = []

    /// Todos claimed by the current user
    @Published private(set) var claimedTodos: [Todo] = []

    /// Lookup dictionaries for todo reference data
    private(set) var categoriesById: [Int: String] = [:]
    private(set) var entitiesById: [Int: String] = [:]

    /// Resolves the category name for a todo
    func categoryName(for todo: Todo) -> String? {
        categoriesById[todo.categoryId]
    }

    /// Resolves the entity name for a todo
    func entityName(for todo: Todo) -> String? {
        entitiesById[todo.entityId]
    }

    // MARK: - Dependencies

    private let discourseRepository: DiscourseRepository
    private let knowledgeRepository: KnowledgeRepository
    private let readingProgressStorage: ReadingProgressStorage
    private let authRepository: AuthRepository
    private let todoRepository: TodoRepository

    // MARK: - Initialization

    init(
        discourseRepository: DiscourseRepository,
        knowledgeRepository: KnowledgeRepository,
        readingProgressStorage: ReadingProgressStorage,
        authRepository: AuthRepository,
        todoRepository: TodoRepository
    ) {
        self.discourseRepository = discourseRepository
        self.knowledgeRepository = knowledgeRepository
        self.readingProgressStorage = readingProgressStorage
        self.authRepository = authRepository
        self.todoRepository = todoRepository
    }

    // MARK: - Public Methods

    /// Loads all dashboard sections concurrently.
    /// Each section fails independently — partial data is shown.
    func loadDashboard() {
        loadState = .loading

        Task {
            // Load user's first name for greeting
            // SSO may return "none" as displayName — fall back to Discourse profile
            if let user = await authRepository.getCurrentUser() {
                let resolvedName: String
                if user.displayName.lowercased().contains("none"),
                   let profile = try? await discourseRepository.fetchUserProfile(username: user.username) {
                    resolvedName = profile.displayText
                } else {
                    resolvedName = user.displayName
                }
                self.userFirstName = resolvedName.components(separatedBy: " ").first
            }

            async let contactsResult = loadRecentContacts()
            async let articlesResult = loadKnowledgeArticles()
            async let topicsResult = loadRecentTopics()
            async let todosResult = loadClaimedTodos()

            let contactsData = await contactsResult
            let articles = await articlesResult
            let topics = await topicsResult
            let todos = await todosResult

            self.recentContacts = contactsData.contacts
            self.unreadMessageCount = contactsData.unreadCount
            self.knowledgeArticles = articles
            self.recentTopics = topics
            self.claimedTodos = todos
            self.loadState = .loaded
        }
    }

    /// Refreshes all dashboard data.
    func refresh() {
        loadDashboard()
    }

    // MARK: - Private Section Loaders

    /// Loads recent contacts and unread message count from message threads.
    /// Extracts unique participants from the most recent threads.
    private func loadRecentContacts() async -> (contacts: [UserSummary], unreadCount: Int) {
        guard let currentUser = await authRepository.getCurrentUser() else {
            return ([], 0)
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

            let unreadCount = threads.filter { !$0.isRead }.count
            return (contacts, unreadCount)
        } catch {
            return ([], 0)
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

    /// Loads todos claimed by the current user, along with reference data.
    private func loadClaimedTodos() async -> [Todo] {
        do {
            let todos = try await todoRepository.fetchTodos()
            let claimed = todos.filter { $0.status == .claimed }

            // Load reference data for name resolution
            let categories = await todoRepository.fetchCategories()
            let entities = await todoRepository.fetchEntities()
            self.categoriesById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
            self.entitiesById = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, "\($0.name) (\($0.entityLevel.displayName))") })

            return claimed
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
