//
//  ContentSectionParser.swift
//  PIRATEN
//

import Foundation

/// Parses a markdown body (after frontmatter removal) into typed `ContentSection` values.
/// Splits by H2 (`## `) headings and recognizes special sections:
/// - "Kurzüberblick" → `.overview` (bullet list)
/// - "Checkliste" → `.checklist` (interactive `- [ ]` / `- [x]` items)
/// - "Nächste Schritte" → `.nextSteps` (bullet list of related topics)
/// - "Mini-Quiz" → skipped (quiz comes from frontmatter)
/// Detects callout blockquotes (`> TIP:`, `> ACHTUNG:`, `> MERKSATZ:`) within sections.
/// Preserves section order from the original markdown.
enum ContentSectionParser {

    // MARK: - Public

    /// Parses a markdown body into an array of `ContentSection` values.
    /// - Parameter body: The markdown text (frontmatter already removed).
    /// - Returns: An ordered array of parsed sections.
    static func parse(_ body: String) -> [ContentSection] {
        let rawSections = splitByH2(body)
        var result: [ContentSection] = []

        for raw in rawSections {
            if let section = parseRawSection(raw) {
                result.append(section)
            }
        }

        return result
    }

    // MARK: - H2 Splitting

    /// A raw section extracted from the markdown, before classification.
    private struct RawSection {
        /// The H2 heading text (nil for content before the first H2)
        let heading: String?
        /// The body lines below the heading
        let body: String
    }

    /// Splits the markdown body into sections by `# ` or `## ` headings.
    /// Content before the first heading becomes a section with `heading: nil`.
    private static func splitByH2(_ body: String) -> [RawSection] {
        let lines = body.components(separatedBy: "\n")
        var sections: [RawSection] = []
        var currentHeading: String? = nil
        var currentLines: [String] = []

        for line in lines {
            let isH1 = line.hasPrefix("# ") && !line.hasPrefix("## ")
            let isH2 = line.hasPrefix("## ") && !line.hasPrefix("### ")
            if isH1 || isH2 {
                // Flush previous section
                let content = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if currentHeading != nil || !content.isEmpty {
                    sections.append(RawSection(heading: currentHeading, body: content))
                }
                let prefixLen = isH1 ? 2 : 3
                currentHeading = String(line.dropFirst(prefixLen)).trimmingCharacters(in: .whitespaces)
                currentLines = []
            } else {
                currentLines.append(line)
            }
        }

        // Flush last section
        let content = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if currentHeading != nil || !content.isEmpty {
            sections.append(RawSection(heading: currentHeading, body: content))
        }

        return sections
    }

    // MARK: - Section Classification

    /// Known heading prefixes for special sections (case-insensitive comparison).
    private static let overviewHeadings = ["kurzüberblick"]
    private static let checklistHeadings = ["checkliste"]
    private static let nextStepsHeadings = ["nächste schritte"]
    private static let quizHeadings = ["mini-quiz"]

    /// Classifies and parses a raw section into a `ContentSection`.
    /// Returns `nil` for sections that should be skipped (e.g. Mini-Quiz).
    private static func parseRawSection(_ raw: RawSection) -> ContentSection? {
        guard let heading = raw.heading else {
            // Content before first H2: treat as text if non-empty
            if raw.body.isEmpty { return nil }
            return parseTextBody(heading: "", body: raw.body)
        }

        let headingLower = heading.lowercased()

        if overviewHeadings.contains(where: { headingLower.hasPrefix($0) }) {
            return parseOverview(raw.body)
        } else if checklistHeadings.contains(where: { headingLower.hasPrefix($0) }) {
            return parseChecklist(raw.body)
        } else if nextStepsHeadings.contains(where: { headingLower.hasPrefix($0) }) {
            return parseNextSteps(raw.body)
        } else if quizHeadings.contains(where: { headingLower.hasPrefix($0) }) {
            return nil // Quiz comes from frontmatter
        } else {
            return parseTextBody(heading: heading, body: raw.body)
        }
    }

    // MARK: - Special Section Parsers

    /// Parses a "Kurzüberblick" section into `.overview` with bullet points.
    private static func parseOverview(_ body: String) -> ContentSection {
        let bullets = parseBulletList(body)
        if bullets.isEmpty {
            // Fallback: if no bullets found, treat whole body as single bullet
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return .overview(trimmed.isEmpty ? [] : [trimmed])
        }
        return .overview(bullets)
    }

    /// Parses a "Checkliste" section into `.checklist` with `ChecklistItem` values.
    private static func parseChecklist(_ body: String) -> ContentSection {
        let lines = body.components(separatedBy: "\n")
        var items: [ChecklistItem] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Match "- [ ] text" or "- [x] text" or "- [X] text"
            if let text = parseChecklistLine(trimmed) {
                items.append(ChecklistItem(id: UUID(), text: text))
            }
        }

        return .checklist(items)
    }

    /// Extracts text from a checklist line like `- [ ] Some task` or `- [x] Done task`.
    private static func parseChecklistLine(_ line: String) -> String? {
        // Pattern: "- [ ] text" or "- [x] text" or "- [X] text"
        let patterns = ["- [ ] ", "- [x] ", "- [X] "]
        for pattern in patterns {
            if line.hasPrefix(pattern) {
                let text = String(line.dropFirst(pattern.count)).trimmingCharacters(in: .whitespaces)
                return text.isEmpty ? nil : text
            }
        }
        return nil
    }

    /// Parses a "Nächste Schritte" section into `.nextSteps` with bullet items.
    private static func parseNextSteps(_ body: String) -> ContentSection {
        let bullets = parseBulletList(body)
        if bullets.isEmpty {
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return .nextSteps(trimmed.isEmpty ? [] : [trimmed])
        }
        return .nextSteps(bullets)
    }

    // MARK: - Text Section with Callout Detection

    /// Parses a generic text section body, extracting any callout blockquotes.
    /// If the entire body is a single callout, returns `.callout`.
    /// Otherwise returns `.text` (callouts within mixed content stay as markdown).
    private static func parseTextBody(heading: String, body: String) -> ContentSection {
        // Check if the body is purely a callout
        if let callout = parseCallout(body) {
            return callout
        }

        // Check if the body contains callouts mixed with other content.
        // Extract callouts as separate sections would break ordering,
        // so we keep them inline as markdown for .text sections.
        return .text(heading: heading, body: body)
    }

    /// Attempts to parse a body as a callout blockquote.
    /// Returns a `.callout` section if the body is a recognized callout block, nil otherwise.
    private static func parseCallout(_ body: String) -> ContentSection? {
        let lines = body.components(separatedBy: "\n")

        // Collect all blockquote lines
        var quoteLines: [String] = []
        var hasNonQuoteContent = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("> ") || trimmed == ">" {
                let content = trimmed.hasPrefix("> ") ? String(trimmed.dropFirst(2)) : ""
                quoteLines.append(content)
            } else {
                hasNonQuoteContent = true
            }
        }

        // Only treat as callout if the body is entirely a blockquote
        guard !quoteLines.isEmpty, !hasNonQuoteContent else { return nil }

        let fullQuote = quoteLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for callout type prefix on the first line
        if let (calloutType, text) = extractCalloutType(fullQuote) {
            return .callout(calloutType, text)
        }

        return nil
    }

    /// Extracts a callout type and remaining text from a blockquote string.
    /// Recognized prefixes: "TIP:", "ACHTUNG:", "MERKSATZ:"
    private static func extractCalloutType(_ text: String) -> (CalloutType, String)? {
        let mappings: [(String, CalloutType)] = [
            ("TIP:", .tip),
            ("ACHTUNG:", .warning),
            ("MERKSATZ:", .keyTakeaway)
        ]

        for (prefix, type) in mappings {
            if text.hasPrefix(prefix) {
                let remainder = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                return (type, remainder)
            }
        }

        return nil
    }

    // MARK: - Utility

    /// Parses lines starting with `- ` or `* ` as a bullet list.
    private static func parseBulletList(_ body: String) -> [String] {
        let lines = body.components(separatedBy: "\n")
        var bullets: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") {
                let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty { bullets.append(text) }
            } else if trimmed.hasPrefix("* ") {
                let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty { bullets.append(text) }
            }
        }

        return bullets
    }
}
