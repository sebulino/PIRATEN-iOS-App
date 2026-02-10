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
///
/// All methods are async to support both in-memory fakes and future network implementations.
/// No HTTP calls are made by implementations until real integration with meine-piraten.de.
@MainActor
protocol TodoRepository {
    /// Fetches all todos for the current user.
    /// - Returns: Array of todos, or empty array if fetch fails
    func fetchTodos() async -> [Todo]

    /// Fetches todos filtered by completion status.
    /// - Parameter completed: If true, returns completed todos; if false, returns pending todos
    /// - Returns: Filtered array of todos
    func fetchTodos(completed: Bool) async -> [Todo]

    /// Fetches a single todo by ID.
    /// - Parameter id: The todo ID
    /// - Returns: The todo if found, nil otherwise
    func fetchTodo(byId id: Int) async -> Todo?

    /// Creates a new todo.
    /// - Parameters:
    ///   - title: The todo title (required, max 200 characters)
    ///   - description: Optional description (max 2000 characters)
    ///   - ownerType: The type of organization that owns this todo
    ///   - ownerId: Identifier of the owning organization
    ///   - ownerName: Display name of the owning organization
    /// - Returns: The created todo
    /// - Throws: TodoError if validation fails or creation fails
    func createTodo(title: String, description: String?, ownerType: OwnerType, ownerId: String, ownerName: String) async throws -> Todo

    /// Claims an open todo for the current user.
    /// - Parameter id: The todo ID to claim
    /// - Returns: The updated todo with status `.claimed`
    /// - Throws: TodoError if the todo is not found or not in `.open` status
    func claimTodo(id: Int) async throws -> Todo

    /// Marks a claimed todo as done.
    /// - Parameter id: The todo ID to complete
    /// - Returns: The updated todo with status `.done`
    /// - Throws: TodoError if the todo is not found or not in `.claimed` status
    func completeTodo(id: Int) async throws -> Todo

    /// Unclaims a claimed todo, returning it to open status.
    /// - Parameter id: The todo ID to unclaim
    /// - Returns: The updated todo with status `.open`
    /// - Throws: TodoError if the todo is not found or not in `.claimed` status
    func unclaimTodo(id: Int) async throws -> Todo

    // MARK: - Comments (stub — backend support unknown)

    /// Fetches comments for a todo.
    /// - Parameter todoId: The todo ID
    /// - Returns: Array of comments, or empty array
    func fetchComments(todoId: Int) async -> [TodoComment]

    /// Adds a comment to a todo.
    /// - Parameters:
    ///   - todoId: The todo ID
    ///   - text: The comment text
    /// - Returns: The created comment
    /// - Throws: TodoError if the todo is not found or the operation fails
    func addComment(todoId: Int, text: String) async throws -> TodoComment

    // MARK: - Deletion (hidden from UI, see D-017)

    /// Deletes a todo by ID. This is an admin/maintenance-only capability.
    /// No UI element exposes this method — it is callable only via debug/internal paths.
    /// - Parameter id: The todo ID to delete
    /// - Throws: TodoError if the todo is not found
    func deleteTodo(id: Int) async throws
}
