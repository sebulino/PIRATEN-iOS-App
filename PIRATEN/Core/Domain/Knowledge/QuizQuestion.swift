//
//  QuizQuestion.swift
//  PIRATEN
//

import Foundation

/// A single quiz question with multiple-choice options.
struct QuizQuestion: Identifiable, Equatable, Codable {
    /// Unique identifier for this question instance
    let id: UUID

    /// The question text
    let question: String

    /// Available answer options
    let options: [String]

    /// Index of the correct answer in `options` (0-based)
    let correctAnswerIndex: Int
}
