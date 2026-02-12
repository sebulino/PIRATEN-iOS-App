//
//  KnowledgeTopicDetailViewModel.swift
//  PIRATEN
//

import Combine
import Foundation

/// ViewModel for the Knowledge Topic detail (lesson) view.
/// Manages content loading, checklist toggle persistence, quiz submission,
/// and reading progress tracking.
@MainActor
final class KnowledgeTopicDetailViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var loadState: KnowledgeLoadState = .idle
    @Published private(set) var content: TopicContent?
    @Published private(set) var progress: TopicProgress
    @Published var expandedSections: Set<Int> = []

    // Quiz state
    @Published var selectedAnswers: [UUID: Int] = [:]
    @Published private(set) var quizSubmitted: Bool = false

    // MARK: - Dependencies

    let topic: KnowledgeTopic
    private let repository: KnowledgeRepository
    private let progressStore: ReadingProgressStorage

    // MARK: - Initialization

    init(
        topic: KnowledgeTopic,
        repository: KnowledgeRepository,
        progressStore: ReadingProgressStorage
    ) {
        self.topic = topic
        self.repository = repository
        self.progressStore = progressStore
        self.progress = progressStore.getProgress(for: topic.id) ?? .unread(topicId: topic.id)

        // Restore quiz state from persisted progress
        if progress.quizCorrectCount != nil {
            quizSubmitted = true
        }
    }

    // MARK: - Computed Properties

    /// Number of correct quiz answers after submission.
    var quizCorrectCount: Int {
        progress.quizCorrectCount ?? 0
    }

    /// Total quiz questions count.
    var quizTotalCount: Int {
        progress.quizTotalCount ?? 0
    }

    /// Whether a checklist item is completed.
    func isChecklistItemCompleted(_ itemId: UUID) -> Bool {
        progress.checklistCompletions[itemId.uuidString] ?? false
    }

    // MARK: - Public Methods

    /// Loads the topic content from the repository.
    func loadContent() {
        guard loadState != .loading else { return }
        loadState = .loading
        Task {
            do {
                let fetchedContent = try await repository.fetchTopicContent(topicId: topic.id)
                self.content = fetchedContent
                self.loadState = .loaded
            } catch let error as KnowledgeError {
                self.loadState = .error(message: error.localizedDescription)
            } catch {
                self.loadState = .error(message: "Ein unbekannter Fehler ist aufgetreten")
            }
        }
    }

    /// Marks the topic as started when the user opens it.
    /// Only transitions from .unread to .started.
    func markAsStarted() {
        guard progress.status == .unread else { return }
        progress.status = .started
        progress.lastOpenedAt = Date()
        progressStore.saveProgress(progress)
    }

    /// Toggles a checklist item's completion state and persists immediately.
    func toggleChecklistItem(_ itemId: UUID) {
        let key = itemId.uuidString
        let current = progress.checklistCompletions[key] ?? false
        progress.checklistCompletions[key] = !current
        progressStore.saveProgress(progress)
        evaluateCompletion()
    }

    /// Submits the quiz, calculates the score, and persists the result.
    func submitQuiz() {
        guard !quizSubmitted else { return }
        guard let questions = topic.quiz, !questions.isEmpty else { return }

        let correctCount = questions.filter { question in
            selectedAnswers[question.id] == question.correctAnswerIndex
        }.count

        progress.quizCorrectCount = correctCount
        progress.quizTotalCount = questions.count
        quizSubmitted = true
        progressStore.saveProgress(progress)
        evaluateCompletion()
    }

    /// Toggles expand/collapse state for a section at a given index.
    func toggleSection(_ index: Int) {
        if expandedSections.contains(index) {
            expandedSections.remove(index)
        } else {
            expandedSections.insert(index)
        }
    }

    /// Whether a section at the given index is expanded.
    func isSectionExpanded(_ index: Int) -> Bool {
        expandedSections.contains(index)
    }

    // MARK: - Private

    /// Evaluates whether the topic should be marked as completed.
    /// Completion rule: all checklist items checked (if any) AND quiz submitted (if any).
    private func evaluateCompletion() {
        guard progress.status != .completed else { return }

        let checklistComplete = checklistFullyCompleted()
        let quizComplete = quizFullyCompleted()

        if checklistComplete && quizComplete {
            progress.status = .completed
            progress.completedAt = Date()
            progressStore.saveProgress(progress)
        }
    }

    /// Returns true if all checklist items are completed, or if there are no checklist items.
    private func checklistFullyCompleted() -> Bool {
        guard let content else { return true }
        let checklistItems = content.sections.compactMap { section -> [ChecklistItem]? in
            if case .checklist(let items) = section { return items }
            return nil
        }.flatMap { $0 }

        if checklistItems.isEmpty { return true }
        return checklistItems.allSatisfy { isChecklistItemCompleted($0.id) }
    }

    /// Returns true if the quiz has been submitted, or if there is no quiz.
    private func quizFullyCompleted() -> Bool {
        guard let questions = topic.quiz, !questions.isEmpty else { return true }
        return quizSubmitted
    }
}
