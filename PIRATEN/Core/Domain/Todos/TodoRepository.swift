//
//  TodoRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

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
}
