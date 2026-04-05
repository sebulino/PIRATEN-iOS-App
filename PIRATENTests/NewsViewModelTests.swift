//
//  NewsViewModelTests.swift
//  PIRATENTests
//

import Combine
import Foundation
import Testing
@testable import PIRATEN

@Suite("NewsViewModel Tests")
@MainActor
struct NewsViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(repository: NewsRepository? = nil) -> NewsViewModel {
        NewsViewModel(newsRepository: repository ?? FakeNewsRepository(), cache: NewsCacheStore())
    }

    /// Waits for loadState to reach `.loaded`.
    private func waitForLoaded(_ vm: NewsViewModel) async throws {
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

    /// Waits for loadState to reach any `.error` case.
    private func waitForError(_ vm: NewsViewModel) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var cancellable: AnyCancellable?
            cancellable = vm.$loadState
                .dropFirst()
                .filter { if case .error = $0 { return true }; return false }
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
        #expect(vm.items.isEmpty)
    }

    @Test("Loading transitions from idle to loaded with items")
    func loadTransitions() async throws {
        let vm = makeViewModel()
        vm.loadNews()

        try await waitForLoaded(vm)
        #expect(vm.loadState == .loaded)
        #expect(!vm.items.isEmpty)
    }

    @Test("Error state set when repository throws")
    func errorState() async throws {
        let failingRepo = FakeNewsRepository()
        failingRepo.shouldThrow = true
        let vm = makeViewModel(repository: failingRepo)
        vm.loadNews()

        try await waitForError(vm)
        if case .error = vm.loadState {
            // Expected
        } else {
            Issue.record("Expected error state but got \(vm.loadState)")
        }
    }

    @Test("Refresh re-fetches items")
    func refresh() async throws {
        let vm = makeViewModel()
        vm.refresh()

        try await waitForLoaded(vm)
        #expect(vm.loadState == .loaded)
        #expect(!vm.items.isEmpty)
    }
}
