//
//  TodosViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation
import Combine

/// Represents the current state of the todos view.
enum TodosLoadState: Equatable {
    /// Initial state, no data loaded yet
    case idle

    /// Currently loading todos
    case loading

    /// Todos loaded successfully (may be empty)
    case loaded

    /// Loading failed with an error message
    case error(message: String)
}

/// ViewModel for the Todos tab.
/// Coordinates between the TodosView and the TodoRepository.
/// Provides published state for SwiftUI data binding.
@MainActor
final class TodosViewModel: ObservableObject {

    // MARK: - Published State

    /// The list of todos to display
    @Published private(set) var todos: [Todo] = []

    /// The current load state of the todos
    @Published private(set) var loadState: TodosLoadState = .idle

    /// Whether there are new todos since the user last viewed the Todos tab
    @Published private(set) var hasNewContent: Bool = false

    private static let lastSeenTodoKey = "todos_last_seen_todo_id"

    /// Convenience property for backward compatibility
    var isLoading: Bool {
        loadState == .loading
    }

    /// Convenience property for backward compatibility
    var errorMessage: String? {
        if case .error(let message) = loadState {
            return message
        }
        return nil
    }

    /// Lookup dictionaries for todo reference data
    private(set) var categoriesById: [Int: String] = [:]
    private(set) var entitiesById: [Int: String] = [:]

    /// Resolves the category name for a todo
    func categoryName(for todo: Todo) -> String? {
        categoriesById[todo.categoryId]
    }

    /// Resolves the entity name (Gliederung) for a todo
    func entityName(for todo: Todo) -> String? {
        entitiesById[todo.entityId]
    }

    // MARK: - Dependencies

    private let todoRepository: TodoRepository
    private let authStateManager: AuthStateManager?

    /// Timer for periodic background polling (every 5 minutes)
    private var pollingTimer: Timer?

    /// Polling interval in seconds (5 minutes)
    private static let pollingInterval: TimeInterval = 300

    // MARK: - Initialization

    /// Creates a TodosViewModel with the given repository.
    /// - Parameters:
    ///   - todoRepository: The repository to fetch todo data from
    ///   - authStateManager: Optional auth state manager for handling session expiry
    init(todoRepository: TodoRepository, authStateManager: AuthStateManager? = nil) {
        self.todoRepository = todoRepository
        self.authStateManager = authStateManager
        startPolling()
    }

    deinit {
        pollingTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Loads the list of todos from the repository.
    /// Updates published state for loading, todos, and errors.
    func loadTodos() {
        loadState = .loading

        Task {
            do {
                let fetchedTodos = try await todoRepository.fetchTodos()

                async let categoriesResult = todoRepository.fetchCategories()
                async let entitiesResult = todoRepository.fetchEntities()
                let categories = await categoriesResult
                let entities = await entitiesResult
                self.categoriesById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
//                self.entitiesById = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, "\($0.name) (\($0.entityLevel.displayName))") })
                self.entitiesById = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, "\($0.name)") })

                self.todos = fetchedTodos
                self.loadState = .loaded
                self.updateNewContentFlag()
            } catch let error as TodoError where error == .unauthorized {
                self.authStateManager?.logout()
            } catch {
                self.loadState = .error(message: "Aufgaben konnten nicht geladen werden. Bitte überprüfe deine Verbindung.")
            }
        }
    }

    /// Refreshes the todo list. Alias for loadTodos for pull-to-refresh.
    func refresh() {
        loadTodos()
    }

    // MARK: - Computed Properties

    /// Returns todos that are open or claimed (not done)
    var pendingTodos: [Todo] {
        todos.filter { $0.status != .done }
    }

    /// Returns only completed (done) todos
    var completedTodos: [Todo] {
        todos.filter { $0.status == .done }
    }

    /// Marks the Todos tab as viewed, clearing the new content indicator.
    func markAsViewed() {
        guard let newestId = todos.first?.id else { return }
        UserDefaults.standard.set(newestId, forKey: Self.lastSeenTodoKey)
        hasNewContent = false
    }

    // MARK: - Private Helpers

    private func updateNewContentFlag() {
        guard let newestId = todos.first?.id else { return }
        let lastSeen = UserDefaults.standard.integer(forKey: Self.lastSeenTodoKey)
        hasNewContent = lastSeen != 0 && newestId != lastSeen
    }

    // MARK: - Polling

    /// Starts a repeating timer that polls for new todos every 5 minutes.
    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: Self.pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollForNewContent()
            }
        }
    }

    /// Fetches todos in the background and updates the new-content badge
    /// without disrupting the current view.
    private func pollForNewContent() async {
        do {
            let fetchedTodos = try await todoRepository.fetchTodos()
            // Only update the badge flag; don't replace the displayed list
            // unless the user hasn't loaded anything yet
            if todos.isEmpty {
                todos = fetchedTodos
                loadState = .loaded
            }
            guard let newestId = fetchedTodos.first?.id else { return }
            let lastSeen = UserDefaults.standard.integer(forKey: Self.lastSeenTodoKey)
            hasNewContent = lastSeen != 0 && newestId != lastSeen
        } catch {
            // Polling failures are silent — don't disturb the user
        }
    }
}
