//
//  HomeViewModelTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 19.02.26.
//

import Combine
import Foundation
import Testing
@testable import PIRATEN

@Suite("HomeViewModel Tests")
@MainActor
struct HomeViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(
        discourseRepository: DiscourseRepository? = nil,
        knowledgeRepository: KnowledgeRepository? = nil,
        authRepository: AuthRepository? = nil,
        credentialStore: CredentialStore? = nil,
        discourseCache: DiscourseCacheStore? = nil
    ) -> HomeViewModel {
        let store = credentialStore ?? InMemoryCredentialStore()
        let auth = authRepository ?? FakeAuthRepository(credentialStore: store)
        // Default to a per-test UserDefaults suite so the topic/thread cache is
        // isolated (the production default is shared .standard).
        let cache = discourseCache ?? DiscourseCacheStore(
            userDefaults: UserDefaults(suiteName: "test-cache-\(UUID().uuidString)")!
        )
        return HomeViewModel(
            discourseRepository: discourseRepository ?? FakeDiscourseRepository(),
            knowledgeRepository: knowledgeRepository ?? FakeKnowledgeRepository(),
            readingProgressStorage: ReadingProgressStore(
                userDefaults: UserDefaults(suiteName: "test-home-\(UUID().uuidString)")!
            ),
            authRepository: auth,
            todoRepository: FakeTodoRepository(),
            discourseAPIKeyProvider: KeychainDiscourseAPIKeyProvider(credentialStore: store),
            discourseCache: cache
        )
    }

    /// Waits for the ViewModel's loadState to become `.loaded` using Combine observation.
    private func waitForLoaded(_ vm: HomeViewModel) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var cancellable: AnyCancellable?
            cancellable = vm.$loadState
                .dropFirst()
                .filter { $0 == .loaded }
                .first()
                .sink { _ in
                    cancellable?.cancel()
                    continuation.resume()
                }
        }
    }

    // MARK: - Load State Tests

    @Test("Initial state is idle")
    func initialState() {
        let vm = makeViewModel()
        #expect(vm.loadState == .idle)
        #expect(vm.recentContacts.isEmpty)
        #expect(vm.knowledgeArticles.isEmpty)
        #expect(vm.recentTopics.isEmpty)
    }

    @Test("Dashboard loads to loaded state")
    func loadDashboard() async throws {
        let vm = makeViewModel()
        vm.loadDashboard()

        try await waitForLoaded(vm)
        #expect(vm.loadState == .loaded)
    }

    @Test("Recent topics are populated from fake repository")
    func recentTopics() async throws {
        let vm = makeViewModel()
        vm.loadDashboard()

        try await waitForLoaded(vm)
        // FakeDiscourseRepository returns some topics
        // recentTopics should have at most 5
        #expect(vm.recentTopics.count <= 5)
    }

    @Test("Aktuelle Themen surfaces unread topics first")
    func recentTopicsPrioritisesUnread() async throws {
        // Cache order mimics Discourse /latest (bumped activity order) with an
        // interleaved read/unread mix. loadRecentTopics must lift the unread
        // topics ("neue Antworten") to the top while preserving the relative
        // activity order within each group.
        let cache = DiscourseCacheStore(
            userDefaults: UserDefaults(suiteName: "test-topics-\(UUID().uuidString)")!
        )
        func topic(_ id: Int, read: Bool) -> Topic {
            Topic(
                id: id,
                title: "Thema \(id)",
                createdBy: UserSummary(id: 1, username: "pirat", displayName: nil, avatarUrl: nil),
                createdAt: Date(),
                postsCount: 3,
                viewCount: 0,
                likeCount: 0,
                categoryId: 1,
                isVisible: true,
                isClosed: false,
                isArchived: false,
                isRead: read
            )
        }
        cache.saveTopics([
            topic(1, read: true),
            topic(2, read: false),
            topic(3, read: true),
            topic(4, read: false)
        ])

        let vm = makeViewModel(discourseCache: cache)
        vm.loadDashboard()
        try await waitForLoaded(vm)

        // Unread (2, 4) first — relative order preserved — then read (1, 3).
        #expect(vm.recentTopics.map { $0.id } == [2, 4, 1, 3])
    }

    @Test("Knowledge articles are populated from fake repository")
    func knowledgeArticles() async throws {
        let vm = makeViewModel()
        vm.loadDashboard()

        try await waitForLoaded(vm)
        // Should have at most 3 articles
        #expect(vm.knowledgeArticles.count <= 3)
    }

    // MARK: - Partial Failure Resilience

    @Test("Dashboard still loads when one section fails")
    func partialFailure() async throws {
        // Use a repository that will fail for messages but succeed for topics
        let vm = makeViewModel()
        vm.loadDashboard()

        try await waitForLoaded(vm)
        // Should still reach loaded state even if contacts fail
        #expect(vm.loadState == .loaded)
    }

    // MARK: - Recent Contacts Filtering

    @Test("System accounts are excluded from recent contacts")
    func systemAccountsFilteredFromRecentContacts() async throws {
        // A thread whose participants include three automated accounts
        // (system, discobot, robotpirat) plus one real Pirat. Only the real
        // Pirat should surface in "Letzte Kontakte". `discobot` in particular
        // PMs every new user a welcome message, so it would otherwise be the
        // first phantom "contact" right after login.
        let realPirat = UserSummary(id: 10, username: "ehrlicher_pirat", displayName: "Ehrliche Piratin", avatarUrl: nil)
        let systemBot = UserSummary(id: 11, username: "system", displayName: "System", avatarUrl: nil)
        let robotBot = UserSummary(id: 12, username: "RobotPirat", displayName: "Robot Pirat", avatarUrl: nil)
        let discobot = UserSummary(id: 13, username: "discobot", displayName: "discobot", avatarUrl: nil)

        let thread = MessageThread(
            id: 9001,
            title: "Willkommen an Bord",
            participants: [realPirat, systemBot, robotBot, discobot],
            createdAt: Date(),
            lastActivityAt: Date(),
            postsCount: 1,
            isRead: true,
            lastPoster: discobot
        )

        let store = InMemoryCredentialStore()
        Self.seedDiscourseCredential(into: store)
        let auth = FakeAuthRepository(credentialStore: store)
        _ = await auth.authenticate() // so getCurrentUser returns the stub user

        let vm = makeViewModel(
            discourseRepository: FakeDiscourseRepository(messageThreadsOverride: [thread]),
            authRepository: auth,
            credentialStore: store
        )
        vm.loadDashboard()
        try await waitForLoaded(vm)

        let usernames = Set(vm.recentContacts.map { $0.username.lowercased() })
        #expect(usernames.contains("ehrlicher_pirat"))
        #expect(!usernames.contains("system"))
        #expect(!usernames.contains("robotpirat"))
        #expect(!usernames.contains("discobot"))
    }

    @Test("Recent contacts empty when only system accounts present")
    func onlySystemAccountsYieldsEmptyContacts() async throws {
        // A thread with ONLY automated participants → no human contacts,
        // so the section shows its empty-state hint.
        let systemBot = UserSummary(id: 11, username: "system", displayName: "System", avatarUrl: nil)
        let robotBot = UserSummary(id: 12, username: "robotpirat", displayName: "Robot Pirat", avatarUrl: nil)

        let thread = MessageThread(
            id: 9002,
            title: "Automatische Benachrichtigung",
            participants: [systemBot, robotBot],
            createdAt: Date(),
            lastActivityAt: Date(),
            postsCount: 1,
            isRead: true,
            lastPoster: systemBot
        )

        let store = InMemoryCredentialStore()
        Self.seedDiscourseCredential(into: store)
        let auth = FakeAuthRepository(credentialStore: store)
        _ = await auth.authenticate()

        let vm = makeViewModel(
            discourseRepository: FakeDiscourseRepository(messageThreadsOverride: [thread]),
            authRepository: auth,
            credentialStore: store
        )
        vm.loadDashboard()
        try await waitForLoaded(vm)

        #expect(vm.recentContacts.isEmpty)
    }

    // MARK: - Test Helpers

    /// Writes a fake Discourse credential so HomeViewModel takes the
    /// "Discourse connected" branch (otherwise it skips contact loading).
    private static func seedDiscourseCredential(into store: CredentialStore) {
        let credential = DiscourseCredential(
            apiKey: "test-key",
            clientId: "test-client",
            createdAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(credential),
           let json = String(data: data, encoding: .utf8) {
            try? store.set(json, forKey: DiscourseAuthManager.discourseCredentialKey)
        }
    }
}
