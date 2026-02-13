//
//  ReadingProgress.swift
//  PIRATEN
//

import Foundation

/// Reading status for a knowledge topic.
enum ReadingStatus: String, Codable, Equatable {
    case unread
    case started
    case completed
}

/// Persisted progress for a single topic, including checklist and quiz state.
struct TopicProgress: Codable, Equatable {
    /// The topic this progress belongs to
    let topicId: String

    /// Current reading status
    var status: ReadingStatus

    /// When the topic was last opened
    var lastOpenedAt: Date?

    /// When the topic was marked as completed
    var completedAt: Date?

    /// Checklist item completions keyed by ChecklistItem.id (as String for Codable)
    var checklistCompletions: [String: Bool]

    /// Number of correct answers in the quiz (nil if quiz not attempted)
    var quizCorrectCount: Int?

    /// Total number of quiz questions (nil if quiz not attempted)
    var quizTotalCount: Int?

    /// Whether the topic has been completed.
    var isCompleted: Bool {
        status == .completed
    }

    /// Whether the topic has been started (but not completed).
    var isStarted: Bool {
        status == .started
    }

    /// Creates a new unread progress entry.
    static func unread(topicId: String) -> TopicProgress {
        TopicProgress(
            topicId: topicId,
            status: .unread,
            checklistCompletions: [:]
        )
    }
}
