//
//  TopicContent.swift
//  PIRATEN
//

import Foundation

/// Type of callout box in lesson content.
enum CalloutType: String, Equatable, Codable {
    /// Helpful tip (blue)
    case tip
    /// Warning or caution (orange)
    case warning
    /// Key takeaway to remember (green)
    case keyTakeaway
}

/// A single item in a checklist section.
struct ChecklistItem: Identifiable, Equatable, Codable {
    /// Unique identifier for toggle persistence
    let id: UUID
    /// The checklist item text
    let text: String
}

/// A parsed section of lesson content, derived from splitting markdown by H2 headings.
enum ContentSection: Equatable, Codable {
    /// "Kurzüberblick" — compact bullet summary (always visible)
    case overview([String])

    /// A standard text section with heading and markdown body
    case text(heading: String, body: String)

    /// "Checkliste" — interactive task list items
    case checklist([ChecklistItem])

    /// Quiz questions (from frontmatter, rendered at bottom)
    case quiz([QuizQuestion])

    /// "Nächste Schritte" — links to related topics
    case nextSteps([String])

    /// Callout box (TIP, ACHTUNG, MERKSATZ)
    case callout(CalloutType, String)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type, bullets, heading, body, items, questions, steps, calloutType, calloutText
    }

    private enum SectionType: String, Codable {
        case overview, text, checklist, quiz, nextSteps, callout
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .overview(let bullets):
            try container.encode(SectionType.overview, forKey: .type)
            try container.encode(bullets, forKey: .bullets)
        case .text(let heading, let body):
            try container.encode(SectionType.text, forKey: .type)
            try container.encode(heading, forKey: .heading)
            try container.encode(body, forKey: .body)
        case .checklist(let items):
            try container.encode(SectionType.checklist, forKey: .type)
            try container.encode(items, forKey: .items)
        case .quiz(let questions):
            try container.encode(SectionType.quiz, forKey: .type)
            try container.encode(questions, forKey: .questions)
        case .nextSteps(let steps):
            try container.encode(SectionType.nextSteps, forKey: .type)
            try container.encode(steps, forKey: .steps)
        case .callout(let calloutType, let text):
            try container.encode(SectionType.callout, forKey: .type)
            try container.encode(calloutType, forKey: .calloutType)
            try container.encode(text, forKey: .calloutText)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(SectionType.self, forKey: .type)
        switch type {
        case .overview:
            let bullets = try container.decode([String].self, forKey: .bullets)
            self = .overview(bullets)
        case .text:
            let heading = try container.decode(String.self, forKey: .heading)
            let body = try container.decode(String.self, forKey: .body)
            self = .text(heading: heading, body: body)
        case .checklist:
            let items = try container.decode([ChecklistItem].self, forKey: .items)
            self = .checklist(items)
        case .quiz:
            let questions = try container.decode([QuizQuestion].self, forKey: .questions)
            self = .quiz(questions)
        case .nextSteps:
            let steps = try container.decode([String].self, forKey: .steps)
            self = .nextSteps(steps)
        case .callout:
            let calloutType = try container.decode(CalloutType.self, forKey: .calloutType)
            let text = try container.decode(String.self, forKey: .calloutText)
            self = .callout(calloutType, text)
        }
    }
}

/// Full content of a knowledge topic, including the raw markdown and parsed sections.
struct TopicContent: Equatable, Codable {
    /// ID of the topic this content belongs to
    let topicId: String

    /// Original raw markdown (kept for fallback rendering)
    let rawMarkdown: String

    /// Parsed structured sections for rendering
    let sections: [ContentSection]
}
