//
//  TodosViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation
import Combine

/// ViewModel for the Todos tab.
/// Coordinates between the TodosView and the TodoRepository.
/// Provides published state for SwiftUI data binding.
@MainActor
final class TodosViewModel: ObservableObject {

    // MARK: - Published State

    /// The list of todos to display
    @Published private(set) var todos: [Todo] = []

    /// Whether todos are currently being loaded
    @Published private(set) var isLoading: Bool = false

    /// Error message if loading failed, nil otherwise
    @Published private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let todoRepository: TodoRepository

    // MARK: - Initialization

    /// Creates a TodosViewModel with the given repository.
    /// - Parameter todoRepository: The repository to fetch todo data from
    init(todoRepository: TodoRepository) {
        self.todoRepository = todoRepository
    }

    // MARK: - Public Methods

    /// Loads the list of todos from the repository.
    /// Updates published state for loading, todos, and errors.
    func loadTodos() {
        isLoading = true
        errorMessage = nil

        Task {
            let fetchedTodos = await todoRepository.fetchTodos()
            self.todos = fetchedTodos
            self.isLoading = false
        }
    }

    /// Refreshes the todo list. Alias for loadTodos for pull-to-refresh.
    func refresh() {
        loadTodos()
    }

    // MARK: - Computed Properties

    /// Returns only pending (not completed) todos
    var pendingTodos: [Todo] {
        todos.filter { !$0.isCompleted }
    }

    /// Returns only completed todos
    var completedTodos: [Todo] {
        todos.filter { $0.isCompleted }
    }
}
