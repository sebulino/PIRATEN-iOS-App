//
//  Todo.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// The type of organization that owns a Todo.
/// Represents the organizational level within the Piratenpartei.
enum OwnerType: String, CaseIterable {
    case kreisverband
    case landesverband
    case bundesverband
    case arbeitsgemeinschaft

    /// German display name for the owner type
    var displayName: String {
        switch self {
        case .kreisverband: return "Kreisverband"
        case .landesverband: return "Landesverband"
        case .bundesverband: return "Bundesverband"
        case .arbeitsgemeinschaft: return "Arbeitsgemeinschaft"
        }
    }
}

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

    /// The type of organization that owns this todo
    let ownerType: OwnerType

    /// Identifier of the owning organization
    let ownerId: String

    /// Display name of the owning organization
    let ownerName: String

    /// When the task was created
    let createdAt: Date

    /// Due date for the task, if set
    let dueDate: Date?

    /// Current lifecycle status of the todo
    let status: TodoStatus

    /// Username of the person who claimed this todo, if any
    let assignee: String?

    /// Priority level of the task (placeholder until API confirms structure)
    let priority: Priority

    /// Task priority levels
    enum Priority: String, CaseIterable {
        case low
        case medium
        case high
    }
}
