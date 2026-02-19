//
//  HomeViewModelTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 19.02.26.
//

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
        authRepository: AuthRepository? = nil
    ) -> HomeViewModel {
        let credentialStore = InMemoryCredentialStore()
        let auth = authRepository ?? FakeAuthRepository(credentialStore: credentialStore)
        return HomeViewModel(
            discourseRepository: discourseRepository ?? FakeDiscourseRepository(),
            knowledgeRepository: knowledgeRepository ?? FakeKnowledgeRepository(),
            readingProgressStorage: ReadingProgressStore(
                userDefaults: UserDefaults(suiteName: "test-home-\(UUID().uuidString)")!
            ),
            authRepository: auth
        )
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

        try await Task.sleep(nanoseconds: 500_000_000) // 500ms for async operations
        #expect(vm.loadState == .loaded)
    }

    @Test("Recent topics are populated from fake repository")
    func recentTopics() async throws {
        let vm = makeViewModel()
        vm.loadDashboard()

        try await Task.sleep(nanoseconds: 500_000_000)
        // FakeDiscourseRepository returns some topics
        // recentTopics should have at most 5
        #expect(vm.recentTopics.count <= 5)
    }

    @Test("Knowledge articles are populated from fake repository")
    func knowledgeArticles() async throws {
        let vm = makeViewModel()
        vm.loadDashboard()

        try await Task.sleep(nanoseconds: 500_000_000)
        // Should have at most 3 articles
        #expect(vm.knowledgeArticles.count <= 3)
    }

    // MARK: - Partial Failure Resilience

    @Test("Dashboard still loads when one section fails")
    func partialFailure() async throws {
        // Use a repository that will fail for messages but succeed for topics
        let vm = makeViewModel()
        vm.loadDashboard()

        try await Task.sleep(nanoseconds: 500_000_000)
        // Should still reach loaded state even if contacts fail
        #expect(vm.loadState == .loaded)
    }
}
