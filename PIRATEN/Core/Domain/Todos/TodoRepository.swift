//
//  TodoRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Typed errors for Todo operations.
enum TodoError: Error, Equatable {
    case titleRequired
    case titleTooLong
    case descriptionTooLong
    case todoNotFound
    case invalidTransition
    case operationFailed(String)
}

/// Protocol defining the Todo repository interface for meine-piraten.de tasks.
/// This abstraction allows swapping implementations (fake/real) without UI changes.
@MainActor
protocol TodoRepository {
    /// Fetches all todos.
    func fetchTodos() async throws -> [Todo]

    /// Fetches todos filtered by completion status.
    func fetchTodos(completed: Bool) async throws -> [Todo]

    /// Fetches a single todo by ID.
    func fetchTodo(byId id: Int) async -> Todo?

    /// Creates a new todo.
    func createTodo(title: String, description: String?, entityId: Int, categoryId: Int, urgent: Bool, dueDate: Date?, activityPoints: Int?, timeNeededInHours: Int?) async throws -> Todo

    /// Claims an open todo for the current user.
    func claimTodo(id: Int) async throws -> Todo

    /// Marks a claimed todo as done.
    func completeTodo(id: Int) async throws -> Todo

    /// Unclaims a claimed todo, returning it to open status.
    func unclaimTodo(id: Int) async throws -> Todo

    // MARK: - Comments

    /// Fetches comments for a todo.
    func fetchComments(todoId: Int) async -> [TodoComment]

    /// Adds a comment to a todo.
    func addComment(todoId: Int, text: String) async throws -> TodoComment

    // MARK: - Deletion (hidden from UI, see D-017)

    /// Deletes a todo by ID.
    func deleteTodo(id: Int) async throws

    // MARK: - Admin Requests

    /// Checks whether the current user has admin status.
    /// Returns `true` if admin, `false` if not, `nil` if the server is unreachable.
    func checkAdminStatus() async -> Bool?

    /// Requests admin access with the given reason.
    func requestAdmin(reason: String) async throws

    // MARK: - Reference Data

    /// Fetches all available entities.
    func fetchEntities() async -> [Entity]

    /// Fetches all available categories.
    func fetchCategories() async -> [TodoCategory]
}
