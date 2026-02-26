//
//  NewsItem.swift
//  PIRATEN
//

import Foundation

/// A news item from the meine-piraten.de news API.
struct NewsItem: Identifiable, Codable, Equatable, Hashable {
    let chatId: Int64
    let messageId: Int64
    let postedAt: Date
    let text: String

    var id: Int64 { messageId }

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case messageId = "message_id"
        case postedAt = "posted_at"
        case text
    }

    /// First line of text, or first two lines joined by " · " if the first starts with "Wer:".
    var headline: String {
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard let first = lines.first else { return text }

        if first.hasPrefix("Wer:"), lines.count > 1 {
            return "\(first) · \(lines[1])"
        }
        return first
    }

    /// Full text — views handle line limiting.
    var previewText: String { text }
}
