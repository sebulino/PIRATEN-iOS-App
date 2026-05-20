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

    /// Text with the leading `<sender>` marker stripped.
    ///
    /// meine-piraten.de's news API prepends the original sender's username
    /// in angle brackets to each item's body text. The marker is redundant
    /// with the news feed's own attribution UI and exposes the sender's
    /// username in user-facing copy unnecessarily.
    ///
    /// Observed shapes (real examples captured 2026-05-20):
    ///
    /// - Single-line, marker + inline content:
    ///   `"<dkluever2025> 18 Uhr Wahlkampfteam MV in Rehna…"`
    ///   →  `"18 Uhr Wahlkampfteam MV in Rehna…"`
    ///
    /// - Multi-line, marker + inline content on first line:
    ///   `"<thebug> Heute ist wieder Sitzung…\nhttps://bbb…"`
    ///   →  `"Heute ist wieder Sitzung…\nhttps://bbb…"`
    ///
    /// - Multi-line, marker + datetime then body:
    ///   `"<Agitatorrr> 2026-05-20 21:00 Uhr: Stammtisch\n…"`
    ///   →  `"2026-05-20 21:00 Uhr: Stammtisch\n…"`
    ///
    /// - Marker alone on first line, body on subsequent lines:
    ///   `"<sebulino>\nWer: AG Test\nMeeting morgen"`
    ///   →  `"Wer: AG Test\nMeeting morgen"`
    ///
    /// Only the FIRST `<…>` marker is stripped, and only if the text
    /// starts with `<`. Angle brackets later in the body (rare, but
    /// possible in quoted text or URLs) are left intact.
    var displayText: String {
        guard text.first == "<",
              let closingBracket = text.firstIndex(of: ">") else {
            return text
        }
        // Walk past the closing bracket and any whitespace that
        // immediately follows it (space, tab, OR newline) so the
        // returned text starts with real content, not residue from
        // the stripped marker.
        let afterBracket = text.index(after: closingBracket)
        let remainder = text[afterBracket...].drop(while: \.isWhitespace)
        return String(remainder)
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
