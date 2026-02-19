//
//  FakeTodoRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Fake implementation of TodoRepository for development and testing.
/// Returns in-memory data. Will be replaced by real meine-piraten.de API integration later.
@MainActor
final class FakeTodoRepository: TodoRepository {

    // MARK: - In-Memory Storage

    private var todos: [Todo]
    private var nextId: Int
    private var comments: [Int: [TodoComment]] = [:]
    private var nextCommentId: Int = 1000

    private let entities: [Entity] = [
        Entity(id: 1, name: "KV Frankfurt", isLV: false, isOV: false, isKV: true, parentEntityId: 2),
        Entity(id: 2, name: "LV Hessen", isLV: true, isOV: false, isKV: false, parentEntityId: nil),
        Entity(id: 3, name: "KV München", isLV: false, isOV: false, isKV: true, parentEntityId: 4),
        Entity(id: 4, name: "LV Bayern", isLV: true, isOV: false, isKV: false, parentEntityId: nil),
        Entity(id: 5, name: "OV Schwabing", isLV: false, isOV: true, isKV: false, parentEntityId: 3)
    ]

    private let categories: [TodoCategory] = [
        TodoCategory(id: 1, name: "Wahlkampf"),
        TodoCategory(id: 2, name: "Verwaltung"),
        TodoCategory(id: 3, name: "Öffentlichkeitsarbeit"),
        TodoCategory(id: 4, name: "Veranstaltung")
    ]

    init() {
        self.todos = Self.makeFakeTodos()
        self.nextId = 100

        self.comments = [
            1: [
                TodoComment(id: 1, todoId: 1, authorName: "pirat42", text: "Kann ich Samstag mitbringen.", createdAt: Date().addingTimeInterval(-86400)),
                TodoComment(id: 2, todoId: 1, authorName: "pirat99", text: "Bitte auch Aufkleber bestellen.", createdAt: Date().addingTimeInterval(-3600))
            ]
        ]
    }

    private static func makeFakeTodos() -> [Todo] {
        [
            Todo(
                id: 1, title: "Wahlkampfmaterial bestellen",
                description: "Flyer und Plakate für den Infostand am Samstag vorbereiten.",
                entityId: 1, categoryId: 1,
                createdAt: Date().addingTimeInterval(-86400 * 3),
                dueDate: Date().addingTimeInterval(86400 * 4),
                status: .open, assignee: nil,
                urgent: true, activityPoints: 10, timeNeededInHours: 2, creatorName: "pirat42"
            ),
            Todo(
                id: 2, title: "Protokoll der letzten Sitzung",
                description: "Protokoll der Kreisvorstandssitzung vom 25.01. ins Wiki eintragen.",
                entityId: 3, categoryId: 2,
                createdAt: Date().addingTimeInterval(-86400 * 5),
                dueDate: Date().addingTimeInterval(-86400 * 1),
                status: .claimed, assignee: "pirat42",
                urgent: false, activityPoints: 5, timeNeededInHours: 1, creatorName: "pirat99"
            ),
            Todo(
                id: 3, title: "Pressemitteilung Digitalisierung",
                description: nil,
                entityId: 2, categoryId: 3,
                createdAt: Date().addingTimeInterval(-86400 * 2),
                dueDate: Date().addingTimeInterval(86400 * 7),
                status: .open, assignee: nil,
                urgent: false, activityPoints: 15, timeNeededInHours: 3, creatorName: "pirat42"
            ),
            Todo(
                id: 4, title: "Social Media Posts vorbereiten",
                description: "3-5 Posts für die kommende Woche zum Thema Netzpolitik.",
                entityId: 1, categoryId: 3,
                createdAt: Date().addingTimeInterval(-86400 * 1),
                dueDate: nil,
                status: .open, assignee: nil,
                urgent: false, activityPoints: nil, timeNeededInHours: nil, creatorName: nil
            ),
            Todo(
                id: 5, title: "Newsletter-Entwurf prüfen",
                description: "Korrekturlesen des monatlichen Newsletters.",
                entityId: 4, categoryId: 3,
                createdAt: Date().addingTimeInterval(-86400 * 7),
                dueDate: Date().addingTimeInterval(-86400 * 2),
                status: .done, assignee: "pirat42",
                urgent: true, activityPoints: 5, timeNeededInHours: 1, creatorName: "pirat99"
            ),
            Todo(
                id: 6, title: "Raumreservierung Stammtisch",
                description: "Raum für den monatlichen Stammtisch im Februar reservieren.",
                entityId: 3, categoryId: 4,
                createdAt: Date().addingTimeInterval(-86400 * 10),
                dueDate: Date().addingTimeInterval(-86400 * 5),
                status: .done, assignee: "pirat99",
                urgent: false, activityPoints: 3, timeNeededInHours: nil, creatorName: "pirat42"
            )
        ]
    }

    // MARK: - TodoRepository

    func fetchTodos() async throws -> [Todo] {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return todos
    }

    func fetchTodos(completed: Bool) async throws -> [Todo] {
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

    func createTodo(title: String, description: String?, entityId: Int, categoryId: Int, urgent: Bool, dueDate: Date?, activityPoints: Int?, timeNeededInHours: Int?) async throws -> Todo {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw TodoError.titleRequired }
        guard trimmedTitle.count <= 200 else { throw TodoError.titleTooLong }
        if let desc = description, desc.count > 2000 { throw TodoError.descriptionTooLong }

        try? await Task.sleep(nanoseconds: 100_000_000)

        let newTodo = Todo(
            id: nextId,
            title: trimmedTitle,
            description: description,
            entityId: entityId,
            categoryId: categoryId,
            createdAt: Date(),
            dueDate: dueDate,
            status: .open,
            assignee: nil,
            urgent: urgent,
            activityPoints: activityPoints,
            timeNeededInHours: timeNeededInHours,
            creatorName: "current_user"
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
            entityId: old.entityId, categoryId: old.categoryId,
            createdAt: old.createdAt, dueDate: old.dueDate,
            status: .claimed, assignee: "current_user",
            urgent: old.urgent, activityPoints: old.activityPoints,
            timeNeededInHours: old.timeNeededInHours, creatorName: old.creatorName
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
            entityId: old.entityId, categoryId: old.categoryId,
            createdAt: old.createdAt, dueDate: old.dueDate,
            status: .completed, assignee: old.assignee,
            urgent: old.urgent, activityPoints: old.activityPoints,
            timeNeededInHours: old.timeNeededInHours, creatorName: old.creatorName
        )
        todos[index] = updated
        return updated
    }

    func uncompleteTodo(id: Int) async throws -> Todo {
        guard let index = todos.firstIndex(where: { $0.id == id }) else {
            throw TodoError.todoNotFound
        }
        guard todos[index].status == .completed else {
            throw TodoError.invalidTransition
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        let old = todos[index]
        let updated = Todo(
            id: old.id, title: old.title, description: old.description,
            entityId: old.entityId, categoryId: old.categoryId,
            createdAt: old.createdAt, dueDate: old.dueDate,
            status: .claimed, assignee: old.assignee,
            urgent: old.urgent, activityPoints: old.activityPoints,
            timeNeededInHours: old.timeNeededInHours, creatorName: old.creatorName
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
            entityId: old.entityId, categoryId: old.categoryId,
            createdAt: old.createdAt, dueDate: old.dueDate,
            status: .open, assignee: nil,
            urgent: old.urgent, activityPoints: old.activityPoints,
            timeNeededInHours: old.timeNeededInHours, creatorName: old.creatorName
        )
        todos[index] = updated
        return updated
    }

    // MARK: - Comments

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

    // MARK: - Admin Requests

    func checkAdminStatus() async -> Bool? {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return false
    }

    func requestAdmin(reason: String) async throws {
        try? await Task.sleep(nanoseconds: 100_000_000)
        // No-op stub
    }

    // MARK: - Reference Data

    func fetchEntities() async -> [Entity] {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return entities
    }

    func fetchCategories() async -> [TodoCategory] {
        try? await Task.sleep(nanoseconds: 100_000_000)
        return categories
    }
}
