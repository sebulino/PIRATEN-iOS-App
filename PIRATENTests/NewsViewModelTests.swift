//
//  NewsViewModelTests.swift
//  PIRATENTests
//

import Foundation
import Testing
@testable import PIRATEN

@Suite("NewsViewModel Tests")
@MainActor
struct NewsViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(repository: NewsRepository? = nil) -> NewsViewModel {
        NewsViewModel(newsRepository: repository ?? FakeNewsRepository())
    }

    // MARK: - Load State Tests

    @Test("Initial state is idle")
    func initialState() {
        let vm = makeViewModel()
        #expect(vm.loadState == .idle)
        #expect(vm.posts.isEmpty)
    }

    @Test("Loading transitions from idle to loaded with posts")
    func loadTransitions() async throws {
        let vm = makeViewModel()
        vm.loadNews()

        try await Task.sleep(nanoseconds: 300_000_000) // 300ms to allow fake delay
        #expect(vm.loadState == .loaded)
        #expect(!vm.posts.isEmpty)
    }

    @Test("Error state set when repository throws")
    func errorState() async throws {
        let failingRepo = FakeNewsRepository()
        failingRepo.shouldThrow = true
        let vm = makeViewModel(repository: failingRepo)
        vm.loadNews()

        try await Task.sleep(nanoseconds: 300_000_000)
        if case .error = vm.loadState {
            // Expected
        } else {
            Issue.record("Expected error state but got \(vm.loadState)")
        }
    }

    @Test("Refresh re-fetches posts")
    func refresh() async throws {
        let vm = makeViewModel()
        vm.refresh()

        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(vm.loadState == .loaded)
        #expect(!vm.posts.isEmpty)
    }
}
