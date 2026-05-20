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

    /// Text with the leading `<username> [datetime]` prefix line stripped.
    /// meine-piraten.de's news API embeds the original sender + datetime as
    /// the first line of each item's text body (`<sebulino> 2026-05-20 …`),
    /// which is redundant with the `postedAt` field that views display
    /// separately and exposes the original poster's username unnecessarily
    /// in the user-facing copy.
    var displayText: String {
        guard text.first == "<" else { return text }

        if let newlineIndex = text.firstIndex(of: "\n") {
            let firstLine = text[..<newlineIndex]
            // Only strip if the first line looks like `<...> ...` — must
            // contain a closing angle bracket too, to avoid eating
            // legitimate content that happens to start with "<".
            if firstLine.contains(">") {
                let remainder = text[text.index(after: newlineIndex)...]
                return String(remainder).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return text
    }

    /// First line of text, or first two lines joined by " · " if the first starts with "Wer:".
    var headline: String {
        let lines = displayText.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard let first = lines.first else { return displayText }

        if first.hasPrefix("Wer:"), lines.count > 1 {
            return "\(first) · \(lines[1])"
        }
        return first
    }

    /// Full text — views handle line limiting.
    var previewText: String { displayText }
}
