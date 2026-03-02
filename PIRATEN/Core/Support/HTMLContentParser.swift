//
//  HTMLContentParser.swift
//  PIRATEN
//
//  Created by Claude Code on 03.02.26.
//

import Foundation
import SwiftUI

/// Utility for parsing HTML content into AttributedString with clickable links.
/// Used to render forum posts and messages with preserved hyperlinks.
enum HTMLContentParser {

    /// Parses HTML content and returns an AttributedString with clickable links.
    /// Falls back to plain text if parsing fails.
    /// - Parameter html: The HTML string to parse
    /// - Returns: AttributedString with links, or plain text fallback
    static func parseToAttributedString(_ html: String) -> AttributedString {
        // First, try to parse as HTML to get an attributed string with links
        if let attributedString = parseHTML(html) {
            return attributedString
        }

        // Fallback: strip HTML and return plain text
        return AttributedString(stripHTML(from: html))
    }

    /// Attempts to parse HTML into an AttributedString using NSAttributedString.
    /// This preserves links and converts them to tappable links in SwiftUI.
    /// Strips hardcoded foreground colors so SwiftUI's `.foregroundColor(.primary)`
    /// can take effect, ensuring legibility in both light and dark mode.
    private static func parseHTML(_ html: String) -> AttributedString? {
        // Wrap in basic HTML structure for proper parsing
        let wrappedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <style>
        body { font-family: -apple-system; font-size: 17px; }
        a { color: #007AFF; }
        </style>
        </head>
        <body>\(html)</body>
        </html>
        """

        guard let data = wrappedHTML.data(using: .utf8) else {
            return nil
        }

        // Parse HTML on main thread (required for NSAttributedString HTML parsing)
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard let nsAttributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }

        // Strip hardcoded foreground colors from non-link text.
        // NSAttributedString HTML parsing bakes in black text color, which is
        // invisible on dark backgrounds. By removing foregroundColor from runs
        // that aren't links, SwiftUI's .foregroundColor(.primary) takes effect.
        var attributed = AttributedString(nsAttributedString)
        for run in attributed.runs {
            let hasLink = run.link != nil
            if !hasLink {
                attributed[run.range].uiKit.foregroundColor = nil
            }
        }
        return attributed
    }

    /// Strips HTML tags from content, preserving only plain text.
    /// Also decodes common HTML entities.
    static func stripHTML(from htmlString: String) -> String {
        let stripped = htmlString
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&#x2F;", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return stripped
    }
}
