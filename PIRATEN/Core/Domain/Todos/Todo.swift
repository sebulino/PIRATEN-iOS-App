//
//  Todo.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Domain model representing a task from meine-piraten.de.
/// This is independent of the actual API JSON shape - DTOs will handle mapping.
///
/// The model is intentionally minimal until the meine-piraten.de API schema is confirmed.
/// See: Docs/OPEN_QUESTIONS.md for API unknowns.
struct Todo: Identifiable, Equatable {
    /// Unique identifier for the todo item
    let id: Int

    /// Title or summary of the task
    let title: String

    /// Detailed description of the task, if available
    let description: String?

    /// The group/organization this task belongs to
    let groupName: String

    /// When the task was created
    let createdAt: Date

    /// Due date for the task, if set
    let dueDate: Date?

    /// Whether the task has been completed
    let isCompleted: Bool

    /// Priority level of the task (placeholder until API confirms structure)
    let priority: Priority

    /// Task priority levels
    enum Priority: String, CaseIterable {
        case low
        case medium
        case high
    }
}
