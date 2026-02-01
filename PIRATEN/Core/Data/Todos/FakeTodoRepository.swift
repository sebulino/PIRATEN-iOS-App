//
//  FakeTodoRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Fake implementation of TodoRepository for development and testing.
/// Returns static in-memory data. Will be replaced by real meine-piraten.de API integration later.
///
/// No HTTP calls are made. All data is hardcoded for UI development.
@MainActor
final class FakeTodoRepository: TodoRepository {

    // MARK: - Stub Data

    /// Static fake todos (placeholder data for development)
    private var fakeTodos: [Todo] {
        [
            Todo(
                id: 1,
                title: "Wahlkampfmaterial bestellen",
                description: "Flyer und Plakate für den Infostand am Samstag vorbereiten.",
                groupName: "AG Öffentlichkeitsarbeit",
                createdAt: Date().addingTimeInterval(-86400 * 3), // 3 days ago
                dueDate: Date().addingTimeInterval(86400 * 4), // 4 days from now
                isCompleted: false,
                priority: .high
            ),
            Todo(
                id: 2,
                title: "Protokoll der letzten Sitzung",
                description: "Protokoll der Kreisvorstandssitzung vom 25.01. ins Wiki eintragen.",
                groupName: "Kreisverband München",
                createdAt: Date().addingTimeInterval(-86400 * 5), // 5 days ago
                dueDate: Date().addingTimeInterval(-86400 * 1), // 1 day ago (overdue)
                isCompleted: false,
                priority: .medium
            ),
            Todo(
                id: 3,
                title: "Pressemitteilung Digitalisierung",
                description: nil,
                groupName: "AG Presse",
                createdAt: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                dueDate: Date().addingTimeInterval(86400 * 7), // 7 days from now
                isCompleted: false,
                priority: .medium
            ),
            Todo(
                id: 4,
                title: "Social Media Posts vorbereiten",
                description: "3-5 Posts für die kommende Woche zum Thema Netzpolitik.",
                groupName: "AG Öffentlichkeitsarbeit",
                createdAt: Date().addingTimeInterval(-86400 * 1), // 1 day ago
                dueDate: nil,
                isCompleted: false,
                priority: .low
            ),
            Todo(
                id: 5,
                title: "Newsletter-Entwurf prüfen",
                description: "Korrekturlesen des monatlichen Newsletters.",
                groupName: "Landesverband Bayern",
                createdAt: Date().addingTimeInterval(-86400 * 7), // 7 days ago
                dueDate: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                isCompleted: true,
                priority: .high
            ),
            Todo(
                id: 6,
                title: "Raumreservierung Stammtisch",
                description: "Raum für den monatlichen Stammtisch im Februar reservieren.",
                groupName: "Kreisverband München",
                createdAt: Date().addingTimeInterval(-86400 * 10), // 10 days ago
                dueDate: Date().addingTimeInterval(-86400 * 5), // 5 days ago
                isCompleted: true,
                priority: .medium
            )
        ]
    }

    // MARK: - TodoRepository

    func fetchTodos() async -> [Todo] {
        // Simulate network delay (placeholder behavior)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        return fakeTodos
    }

    func fetchTodos(completed: Bool) async -> [Todo] {
        // Simulate network delay (placeholder behavior)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        return fakeTodos.filter { $0.isCompleted == completed }
    }

    func fetchTodo(byId id: Int) async -> Todo? {
        // Simulate network delay (placeholder behavior)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        return fakeTodos.first { $0.id == id }
    }
}
