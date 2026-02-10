//
//  FakeTodoRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Fake implementation of TodoRepository for development and testing.
/// Returns in-memory data. Will be replaced by real meine-piraten.de API integration later.
///
/// No HTTP calls are made. All data is hardcoded for UI development.
@MainActor
final class FakeTodoRepository: TodoRepository {

    // MARK: - In-Memory Storage

    /// Mutable in-memory todos for create/update operations
    private var todos: [Todo]

    /// Auto-incrementing ID for new todos
    private var nextId: Int

    /// In-memory comment storage keyed by todo ID
    private var comments: [Int: [TodoComment]] = [:]

    /// Auto-incrementing ID for new comments
    private var nextCommentId: Int = 1000

    init() {
        self.todos = Self.makeFakeTodos()
        self.nextId = 100

        // Seed some fake comments
        self.comments = [
            1: [
                TodoComment(id: 1, todoId: 1, authorName: "pirat42", text: "Kann ich Samstag mitbringen.", createdAt: Date().addingTimeInterval(-86400)),
                TodoComment(id: 2, todoId: 1, authorName: "pirat99", text: "Bitte auch Aufkleber bestellen.", createdAt: Date().addingTimeInterval(-3600))
            ]
        ]
    }

    /// Static fake todos (placeholder data for development)
    private static func makeFakeTodos() -> [Todo] {
        [
            Todo(
                id: 1,
                title: "Wahlkampfmaterial bestellen",
                description: "Flyer und Plakate für den Infostand am Samstag vorbereiten.",
                ownerType: .arbeitsgemeinschaft,
                ownerId: "ag-oeffentlichkeitsarbeit",
                ownerName: "AG Öffentlichkeitsarbeit",
                createdAt: Date().addingTimeInterval(-86400 * 3),
                dueDate: Date().addingTimeInterval(86400 * 4),
                status: .open,
                assignee: nil,
                priority: .high
            ),
            Todo(
                id: 2,
                title: "Protokoll der letzten Sitzung",
                description: "Protokoll der Kreisvorstandssitzung vom 25.01. ins Wiki eintragen.",
                ownerType: .kreisverband,
                ownerId: "kv-muenchen",
                ownerName: "Kreisverband München",
                createdAt: Date().addingTimeInterval(-86400 * 5),
                dueDate: Date().addingTimeInterval(-86400 * 1),
                status: .claimed,
                assignee: "pirat42",
                priority: .medium
            ),
            Todo(
                id: 3,
                title: "Pressemitteilung Digitalisierung",
                description: nil,
                ownerType: .arbeitsgemeinschaft,
                ownerId: "ag-presse",
                ownerName: "AG Presse",
                createdAt: Date().addingTimeInterval(-86400 * 2),
                dueDate: Date().addingTimeInterval(86400 * 7),
                status: .open,
                assignee: nil,
                priority: .medium
            ),
            Todo(
                id: 4,
                title: "Social Media Posts vorbereiten",
                description: "3-5 Posts für die kommende Woche zum Thema Netzpolitik.",
                ownerType: .arbeitsgemeinschaft,
                ownerId: "ag-oeffentlichkeitsarbeit",
                ownerName: "AG Öffentlichkeitsarbeit",
                createdAt: Date().addingTimeInterval(-86400 * 1),
                dueDate: nil,
                status: .open,
                assignee: nil,
                priority: .low
            ),
            Todo(
                id: 5,
                title: "Newsletter-Entwurf prüfen",
                description: "Korrekturlesen des monatlichen Newsletters.",
                ownerType: .landesverband,
                ownerId: "lv-bayern",
                ownerName: "Landesverband Bayern",
                createdAt: Date().addingTimeInterval(-86400 * 7),
                dueDate: Date().addingTimeInterval(-86400 * 2),
                status: .done,
                assignee: "pirat42",
                priority: .high
            ),
            Todo(
                id: 6,
                title: "Raumreservierung Stammtisch",
                description: "Raum für den monatlichen Stammtisch im Februar reservieren.",
                ownerType: .kreisverband,
                ownerId: "kv-muenchen",
                ownerName: "Kreisverband München",
                createdAt: Date().addingTimeInterval(-86400 * 10),
                dueDate: Date().addingTimeInterval(-86400 * 5),
                status: .done,
                assignee: "pirat99",
                priority: .medium
            )
        ]
    }

    // MARK: - TodoRepository

    func fetchTodos() async -> [Todo] {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return todos
    }

    func fetchTodos(completed: Bool) async -> [Todo] {
        try? await Task.sleep(nanoseconds: 100_000_000)
        if completed {
            return todos.filter { $0.status == .done }
        } else {
            return todos.filter { $0.status != .done }
        }
    }

    func fetchTodo(byId id: Int) async -> Todo? {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return todos.first { $0.id == id }
    }

    func createTodo(title: String, description: String?, ownerType: OwnerType, ownerId: String, ownerName: String) async throws -> Todo {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw TodoError.titleRequired }
        guard trimmedTitle.count <= 200 else { throw TodoError.titleTooLong }
        if let desc = description, desc.count > 2000 { throw TodoError.descriptionTooLong }

        try? await Task.sleep(nanoseconds: 100_000_000)

        let newTodo = Todo(
            id: nextId,
            title: trimmedTitle,
            description: description,
            ownerType: ownerType,
            ownerId: ownerId,
            ownerName: ownerName,
            createdAt: Date(),
            dueDate: nil,
            status: .open,
            assignee: nil,
            priority: .medium
        )
        nextId += 1
        todos.insert(newTodo, at: 0)
        return newTodo
    }

    func claimTodo(id: Int) async throws -> Todo {
        guard let index = todos.firstIndex(where: { $0.id == id }) else {
            throw TodoError.todoNotFound
        }
        guard todos[index].status == .open else {
            throw TodoError.invalidTransition
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        let old = todos[index]
        let updated = Todo(
            id: old.id, title: old.title, description: old.description,
            ownerType: old.ownerType, ownerId: old.ownerId, ownerName: old.ownerName,
            createdAt: old.createdAt, dueDate: old.dueDate,
            status: .claimed, assignee: "current_user",
            priority: old.priority
        )
        todos[index] = updated
        return updated
    }

    func completeTodo(id: Int) async throws -> Todo {
        guard let index = todos.firstIndex(where: { $0.id == id }) else {
            throw TodoError.todoNotFound
        }
        guard todos[index].status == .claimed else {
            throw TodoError.invalidTransition
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        let old = todos[index]
        let updated = Todo(
            id: old.id, title: old.title, description: old.description,
            ownerType: old.ownerType, ownerId: old.ownerId, ownerName: old.ownerName,
            createdAt: old.createdAt, dueDate: old.dueDate,
            status: .done, assignee: old.assignee,
            priority: old.priority
        )
        todos[index] = updated
        return updated
    }

    func unclaimTodo(id: Int) async throws -> Todo {
        guard let index = todos.firstIndex(where: { $0.id == id }) else {
            throw TodoError.todoNotFound
        }
        guard todos[index].status == .claimed else {
            throw TodoError.invalidTransition
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        let old = todos[index]
        let updated = Todo(
            id: old.id, title: old.title, description: old.description,
            ownerType: old.ownerType, ownerId: old.ownerId, ownerName: old.ownerName,
            createdAt: old.createdAt, dueDate: old.dueDate,
            status: .open, assignee: nil,
            priority: old.priority
        )
        todos[index] = updated
        return updated
    }

    // MARK: - Comments (stub)

    func fetchComments(todoId: Int) async -> [TodoComment] {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return comments[todoId] ?? []
    }

    func addComment(todoId: Int, text: String) async throws -> TodoComment {
        guard todos.contains(where: { $0.id == todoId }) else {
            throw TodoError.todoNotFound
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        let comment = TodoComment(
            id: nextCommentId,
            todoId: todoId,
            authorName: "current_user",
            text: text,
            createdAt: Date()
        )
        nextCommentId += 1
        comments[todoId, default: []].append(comment)
        return comment
    }

    // MARK: - Deletion (hidden from UI)

    func deleteTodo(id: Int) async throws {
        guard let index = todos.firstIndex(where: { $0.id == id }) else {
            throw TodoError.todoNotFound
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        todos.remove(at: index)
        comments.removeValue(forKey: id)
    }
}
