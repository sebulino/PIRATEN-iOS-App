//
//  TodoCategory.swift
//  PIRATEN
//
//  Created by Claude Code on 10.02.26.
//

import Foundation

/// Domain model representing a task category.
/// Named TodoCategory to avoid collision with Swift's built-in Category type.
/// Matches the categories table in the meine-piraten.de Rails server.
struct TodoCategory: Identifiable, Equatable {
    let id: Int
    let name: String
}
