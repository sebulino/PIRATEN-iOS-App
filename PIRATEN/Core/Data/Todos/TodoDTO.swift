//
//  TodoDTO.swift
//  PIRATEN
//
//  Created by Claude Code on 10.02.26.
//

import Foundation

/// DTO matching the Rails tasks JSON response.
struct TaskDTO: Decodable {
    let id: Int
    let title: String
    let description: String?
    let completed: Bool?
    let creatorName: String?
    let timeNeededInHours: Int?
    let dueDate: String?
    let urgent: Bool?
    let activityPoints: Int?
    let categoryId: Int
    let entityId: Int
    let status: String?
    let assignee: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, description, completed, urgent, assignee, status
        case creatorName = "creator_name"
        case timeNeededInHours = "time_needed_in_hours"
        case dueDate = "due_date"
        case activityPoints = "activity_points"
        case categoryId = "category_id"
        case entityId = "entity_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func toDomainModel() -> Todo {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let createdDate = dateFormatter.date(from: createdAt) ?? Date()

        var dueDateValue: Date?
        if let dueDate = dueDate {
            // due_date is a date string like "2025-06-01" (no time component)
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "yyyy-MM-dd"
            dueDateValue = dayFormatter.date(from: dueDate)
        }

        let todoStatus: TodoStatus
        switch status {
        case "claimed": todoStatus = .claimed
        case "done": todoStatus = .done
        default: todoStatus = .open
        }

        return Todo(
            id: id,
            title: title,
            description: description,
            entityId: entityId,
            categoryId: categoryId,
            createdAt: createdDate,
            dueDate: dueDateValue,
            status: todoStatus,
            assignee: assignee,
            urgent: urgent ?? false,
            activityPoints: activityPoints,
            timeNeededInHours: timeNeededInHours,
            creatorName: creatorName
        )
    }
}

/// DTO matching the Rails entities JSON response.
struct EntityDTO: Decodable {
    let id: Int
    let name: String
    let lv: Bool?
    let ov: Bool?
    let kv: Bool?
    let entityId: Int?

    enum CodingKeys: String, CodingKey {
        case id, name
        case lv = "LV"
        case ov = "OV"
        case kv = "KV"
        case entityId = "entity_id"
    }

    func toDomainModel() -> Entity {
        Entity(
            id: id,
            name: name,
            isLV: lv ?? false,
            isOV: ov ?? false,
            isKV: kv ?? false,
            parentEntityId: entityId
        )
    }
}

/// DTO matching the Rails categories JSON response.
struct CategoryDTO: Decodable {
    let id: Int
    let name: String

    func toDomainModel() -> TodoCategory {
        TodoCategory(id: id, name: name)
    }
}

/// DTO matching the Rails comments JSON response.
struct CommentDTO: Decodable {
    let id: Int
    let taskId: Int
    let authorName: String?
    let text: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, text
        case taskId = "task_id"
        case authorName = "author_name"
        case createdAt = "created_at"
    }

    func toDomainModel() -> TodoComment {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let createdDate = dateFormatter.date(from: createdAt) ?? Date()

        return TodoComment(
            id: id,
            todoId: taskId,
            authorName: authorName ?? "",
            text: text,
            createdAt: createdDate
        )
    }
}
