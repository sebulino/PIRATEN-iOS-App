//
//  ReadingProgressStoreTests.swift
//  PIRATENTests
//

import Foundation
import Testing
@testable import PIRATEN

struct ReadingProgressStoreTests {

    // MARK: - Helpers

    /// Creates an isolated UserDefaults instance for each test.
    private func makeIsolatedStore() -> (ReadingProgressStore, UserDefaults) {
        let suiteName = "test.progress.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = ReadingProgressStore(userDefaults: defaults)
        return (store, defaults)
    }

    // MARK: - Basic Operations

    @Test func getProgressReturnsNilForUnknownTopic() {
        let (store, _) = makeIsolatedStore()
        let progress = store.getProgress(for: "nonexistent")
        #expect(progress == nil)
    }

    @Test func saveAndRetrieveProgress() {
        let (store, _) = makeIsolatedStore()

        let progress = TopicProgress(
            topicId: "topic-1",
            status: .started,
            lastOpenedAt: Date(),
            checklistCompletions: [:]
        )
        store.saveProgress(progress)

        let retrieved = store.getProgress(for: "topic-1")
        #expect(retrieved != nil)
        #expect(retrieved?.topicId == "topic-1")
        #expect(retrieved?.status == .started)
    }

    @Test func saveOverwritesExistingProgress() {
        let (store, _) = makeIsolatedStore()

        let initial = TopicProgress(
            topicId: "topic-1",
            status: .started,
            checklistCompletions: [:]
        )
        store.saveProgress(initial)

        let updated = TopicProgress(
            topicId: "topic-1",
            status: .completed,
            completedAt: Date(),
            checklistCompletions: ["item-1": true]
        )
        store.saveProgress(updated)

        let retrieved = store.getProgress(for: "topic-1")
        #expect(retrieved?.status == .completed)
        #expect(retrieved?.checklistCompletions["item-1"] == true)
    }

    @Test func getAllProgressReturnsEmptyDictWhenNothingSaved() {
        let (store, _) = makeIsolatedStore()
        let all = store.getAllProgress()
        #expect(all.isEmpty)
    }

    @Test func getAllProgressReturnsAllEntries() {
        let (store, _) = makeIsolatedStore()

        store.saveProgress(TopicProgress(topicId: "a", status: .started, checklistCompletions: [:]))
        store.saveProgress(TopicProgress(topicId: "b", status: .completed, checklistCompletions: [:]))
        store.saveProgress(TopicProgress(topicId: "c", status: .unread, checklistCompletions: [:]))

        let all = store.getAllProgress()
        #expect(all.count == 3)
        #expect(all["a"]?.status == .started)
        #expect(all["b"]?.status == .completed)
        #expect(all["c"]?.status == .unread)
    }

    // MARK: - Checklist and Quiz

    @Test func savesChecklistCompletions() {
        let (store, _) = makeIsolatedStore()

        let progress = TopicProgress(
            topicId: "topic-1",
            status: .started,
            checklistCompletions: [
                "item-1": true,
                "item-2": false,
                "item-3": true
            ]
        )
        store.saveProgress(progress)

        let retrieved = store.getProgress(for: "topic-1")
        #expect(retrieved?.checklistCompletions.count == 3)
        #expect(retrieved?.checklistCompletions["item-1"] == true)
        #expect(retrieved?.checklistCompletions["item-2"] == false)
        #expect(retrieved?.checklistCompletions["item-3"] == true)
    }

    @Test func savesQuizResults() {
        let (store, _) = makeIsolatedStore()

        let progress = TopicProgress(
            topicId: "topic-1",
            status: .completed,
            checklistCompletions: [:],
            quizCorrectCount: 3,
            quizTotalCount: 5
        )
        store.saveProgress(progress)

        let retrieved = store.getProgress(for: "topic-1")
        #expect(retrieved?.quizCorrectCount == 3)
        #expect(retrieved?.quizTotalCount == 5)
    }

    // MARK: - Clear

    @Test func clearAllRemovesEverything() {
        let (store, _) = makeIsolatedStore()

        store.saveProgress(TopicProgress(topicId: "a", status: .started, checklistCompletions: [:]))
        store.saveProgress(TopicProgress(topicId: "b", status: .completed, checklistCompletions: [:]))

        #expect(store.getAllProgress().count == 2)

        store.clearAll()

        #expect(store.getAllProgress().isEmpty)
        #expect(store.getProgress(for: "a") == nil)
        #expect(store.getProgress(for: "b") == nil)
    }

    // MARK: - Isolation

    @Test func separateStoresAreIsolated() {
        let (store1, _) = makeIsolatedStore()
        let (store2, _) = makeIsolatedStore()

        store1.saveProgress(TopicProgress(topicId: "topic-1", status: .started, checklistCompletions: [:]))

        #expect(store1.getProgress(for: "topic-1") != nil)
        #expect(store2.getProgress(for: "topic-1") == nil)
    }

    // MARK: - Corrupted Data

    @Test func corruptedDataReturnsEmpty() {
        let suiteName = "test.progress.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        // Write invalid data directly
        defaults.set(Data("not valid json".utf8), forKey: "piraten_knowledge_progress")

        let store = ReadingProgressStore(userDefaults: defaults)
        let all = store.getAllProgress()
        #expect(all.isEmpty)

        // After reading corrupted data, it should be cleared
        #expect(defaults.data(forKey: "piraten_knowledge_progress") == nil)
    }
}
