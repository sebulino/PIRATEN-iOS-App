//
//  Todo.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Lifecycle status of a Todo.
enum TodoStatus: String, CaseIterable {
    case open
    case claimed
    case done

    /// German display name for the status
    var displayName: String {
        switch self {
        case .open: return "Offen"
        case .claimed: return "Übernommen"
        case .done: return "Erledigt"
        }
    }
}

/// Domain model representing a task from meine-piraten.de.
/// Aligned to the Rails server schema (tasks table).
struct Todo: Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String?
    let entityId: Int
    let categoryId: Int
    let createdAt: Date
    let dueDate: Date?
    let status: TodoStatus
    let assignee: String?
    let urgent: Bool
    let activityPoints: Int?
    let timeNeededInHours: Int?
    let creatorName: String?
}
