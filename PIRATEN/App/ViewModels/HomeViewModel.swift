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

    /// Whether the Discourse forum needs (re-)authentication
    @Published private(set) var discourseNeedsAuth: Bool = false

    // MARK: - Dependencies

    private let discourseRepository: DiscourseRepository
    private let knowledgeRepository: KnowledgeRepository
    private let readingProgressStorage: ReadingProgressStorage
    private let authRepository: AuthRepository
    private let todoRepository: TodoRepository
    private let discourseAPIKeyProvider: DiscourseAPIKeyProvider
    private let discourseCache: DiscourseCacheStore

    // MARK: - Initialization

    init(
        discourseRepository: DiscourseRepository,
        knowledgeRepository: KnowledgeRepository,
        readingProgressStorage: ReadingProgressStorage,
        authRepository: AuthRepository,
        todoRepository: TodoRepository,
        discourseAPIKeyProvider: DiscourseAPIKeyProvider,
        discourseCache: DiscourseCacheStore = DiscourseCacheStore()
    ) {
        self.discourseRepository = discourseRepository
        self.knowledgeRepository = knowledgeRepository
        self.readingProgressStorage = readingProgressStorage
        self.authRepository = authRepository
        self.todoRepository = todoRepository
        self.discourseAPIKeyProvider = discourseAPIKeyProvider
        self.discourseCache = discourseCache
    }

    // MARK: - Public Methods

    /// Loads all dashboard sections concurrently.
    /// Each section fails independently — partial data is shown.
    func loadDashboard() {
        Task { await performLoad() }
    }

    /// Refreshes all dashboard data and awaits completion.
    func refresh() async {
        await performLoad()
    }

    /// Clears the Discourse auth flag and reloads dashboard data.
    func clearDiscourseAuthFlag() {
        discourseNeedsAuth = false
        loadDashboard()
    }

    private func performLoad() async {
        loadState = .loading

        let hasDiscourseCredential = discourseAPIKeyProvider.hasValidCredential()

        // Topics and contacts now read from the shared cache (no Discourse API calls).
        // ForumViewModel and MessagesViewModel populate the cache.
        self.recentTopics = loadRecentTopics()

        if hasDiscourseCredential {
            async let userNameResult = resolveUserName()
            async let contactsResult = loadRecentContacts()
            async let articlesResult = loadKnowledgeArticles()
            async let todosResult = loadClaimedTodos()

            self.userFirstName = await userNameResult
            let contactsData = await contactsResult
            let articles = await articlesResult
            let todos = await todosResult

            self.recentContacts = contactsData.contacts
            self.unreadMessageCount = contactsData.unreadCount
            self.knowledgeArticles = articles
            self.claimedTodos = todos
        } else {
            // No Discourse credential — skip Discourse sections, load the rest
            self.discourseNeedsAuth = true
            self.recentContacts = []
            self.unreadMessageCount = 0

            // Resolve name from auth repo only (skip Discourse fallback)
            if let user = await authRepository.getCurrentUser() {
                self.userFirstName = user.displayName.components(separatedBy: " ").first
            }

            async let articlesResult = loadKnowledgeArticles()
            async let todosResult = loadClaimedTodos()
            self.knowledgeArticles = await articlesResult
            self.claimedTodos = await todosResult
        }

        self.loadState = .loaded
    }

    /// Updates the unread message count from an external source (e.g. after closing Messages sheet).
    func updateUnreadMessageCount(_ count: Int) {
        unreadMessageCount = count
    }

    // MARK: - Private Section Loaders

    /// Resolves the user's first name for the greeting.
    /// SSO may return "none" as displayName — falls back to Discourse profile.
    private func resolveUserName() async -> String? {
        guard let user = await authRepository.getCurrentUser() else { return nil }
        let resolvedName: String
        if user.displayName.lowercased().contains("none") {
            do {
                let profile = try await discourseRepository.fetchUserProfile(username: user.username)
                resolvedName = profile.displayText
            } catch let error as DiscourseRepositoryError where error == .notAuthenticated {
                self.discourseNeedsAuth = true
                resolvedName = user.displayName
            } catch {
                resolvedName = user.displayName
            }
        } else {
            resolvedName = user.displayName
        }
        return resolvedName.components(separatedBy: " ").first
    }

    /// Loads recent contacts and unread message count from the shared cache.
    /// MessagesViewModel is responsible for fetching and caching message threads;
    /// HomeViewModel reads the cache to avoid duplicate Discourse API calls.
    private func loadRecentContacts() async -> (contacts: [UserSummary], unreadCount: Int) {
        guard let currentUser = await authRepository.getCurrentUser() else {
            return ([], 0)
        }

        // Pre-Bug-#1: Home used to read whatever was in the cache, which on
        // a cold start was empty or stale until the user opened the Messages
        // tab. Now we fetch fresh threads ourselves and ALSO write them to
        // the cache so the Messages tab gets the result for free. Failure
        // falls back to whatever's cached — the dashboard never blocks on
        // a slow Discourse response.
        var threads = discourseCache.cachedMessageThreads()
        do {
            // includeSent: true so the cache write is complete and the
            // Messages tab (which loads inbox + outbox) doesn't have to
            // re-fetch on first open.
            let fetched = try await discourseRepository.fetchMessageThreads(
                for: currentUser.username,
                includeSent: true
            )
            threads = fetched
            discourseCache.saveMessageThreads(fetched)
        } catch {
            // Keep the cached threads; Messages tab will retry on its own.
        }

        var seen = Set<Int>()
        var contacts: [UserSummary] = []

        for thread in threads {
            for participant in thread.participants {
                let username = participant.username
                // Skip self, duplicates, and automated/system accounts.
                // System accounts (e.g. "system", "discobot") send automated
                // PMs but are not real Piraten the user would want to message
                // back, so they don't belong in "Letzte Kontakte". The
                // exclusion list is canonical (see `SystemAccounts`).
                guard username != currentUser.username,
                      !SystemAccounts.isSystem(username),
                      !seen.contains(participant.id)
                else { continue }
                seen.insert(participant.id)
                contacts.append(participant)
            }
            if contacts.count >= 10 { break }
        }

        let unreadCount = threads.filter { !$0.isRead }.count
        return (contacts, unreadCount)
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
            async let categoriesResult = todoRepository.fetchCategories()
            async let entitiesResult = todoRepository.fetchEntities()
            let categories = await categoriesResult
            let entities = await entitiesResult
            self.categoriesById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
            self.entitiesById = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, "\($0.name) (\($0.entityLevel.displayName))") })

            return claimed
        } catch {
            return []
        }
    }

    /// Loads the most recent forum topics from the shared cache.
    /// ForumViewModel is responsible for fetching and caching topics;
    /// HomeViewModel reads the cache to avoid duplicate Discourse API calls.
    private func loadRecentTopics() -> [Topic] {
        return Array(discourseCache.cachedTopics().prefix(5))
    }
}
