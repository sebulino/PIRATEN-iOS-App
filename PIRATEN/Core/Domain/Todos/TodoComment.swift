//
//  TodoComment.swift
//  PIRATEN
//
//  Created by Claude Code on 10.02.26.
//

import Foundation

/// Domain model for a comment on a Todo.
/// Stub implementation — backend support for comments is unknown (see Q-003).
struct TodoComment: Identifiable, Equatable {
    let id: Int
    let todoId: Int
    let authorName: String
    let text: String
    let createdAt: Date
}
