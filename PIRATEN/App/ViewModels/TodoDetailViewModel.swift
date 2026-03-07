//
//  TodoDetailViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 10.02.26.
//

import Foundation
import Combine

/// ViewModel for the Todo detail view.
/// Handles claim, complete, and unclaim actions with optimistic updates.
@MainActor
final class TodoDetailViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var todo: Todo
    @Published private(set) var isPerformingAction: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var comments: [TodoComment] = []
    @Published private(set) var isLoadingComments: Bool = false
    @Published var commentText: String = ""
    @Published private(set) var isSendingComment: Bool = false
    @Published private(set) var categoryName: String?
    @Published private(set) var entityName: String?

    // MARK: - Dependencies

    private let todoRepository: TodoRepository

    // MARK: - Initialization

    init(todo: Todo, todoRepository: TodoRepository) {
        self.todo = todo
        self.todoRepository = todoRepository
    }

    // MARK: - Actions

    /// Claims the todo for the current user.
    /// Optimistically updates status, reverts on failure.
    func claim() {
        performAction { [self] in
            try await todoRepository.claimTodo(id: todo.id)
        }
    }

    /// Marks the todo as completed.
    /// Optimistically updates status, reverts on failure.
    func complete() {
        performAction { [self] in
            try await todoRepository.completeTodo(id: todo.id)
        }
    }

    /// Marks a completed todo back to claimed status.
    /// Optimistically updates status, reverts on failure.
    func uncomplete() {
        performAction { [self] in
            try await todoRepository.uncompleteTodo(id: todo.id)
        }
    }

    /// Unclaims the todo, returning it to open status.
    /// Optimistically updates status, reverts on failure.
    func unclaim() {
        performAction { [self] in
            try await todoRepository.unclaimTodo(id: todo.id)
        }
    }

    // MARK: - Reference Data

    /// Loads category and entity names for display.
    func loadReferenceData() {
        Task {
            let categories = await todoRepository.fetchCategories()
            let entities = await todoRepository.fetchEntities()
            self.categoryName = categories.first { $0.id == todo.categoryId }?.name
            self.entityName = entities.first { $0.id == todo.entityId }?.name
        }
    }

    // MARK: - Comments (stub — backend support unknown)

    /// Loads comments for this todo.
    func loadComments() {
        isLoadingComments = true
        Task {
            self.comments = await todoRepository.fetchComments(todoId: todo.id)
            self.isLoadingComments = false
        }
    }

    /// Adds a comment to this todo.
    func sendComment() {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSendingComment else { return }

        isSendingComment = true
        Task {
            do {
                let comment = try await todoRepository.addComment(todoId: todo.id, text: text)
                self.comments.append(comment)
                self.commentText = ""
            } catch {
                self.errorMessage = "Kommentar konnte nicht gesendet werden."
            }
            self.isSendingComment = false
        }
    }

    // MARK: - Private

    private func performAction(_ action: @escaping () async throws -> Todo) {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        errorMessage = nil

        let previousTodo = todo

        Task {
            do {
                let updated = try await action()
                self.todo = updated
            } catch {
                self.todo = previousTodo
                self.errorMessage = "Aktion fehlgeschlagen. Bitte erneut versuchen."
            }
            self.isPerformingAction = false
        }
    }
}
