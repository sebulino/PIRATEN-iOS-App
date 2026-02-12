//
//  FrontmatterParser.swift
//  PIRATEN
//

import Foundation

/// Result of parsing a markdown file's YAML frontmatter block.
nonisolated struct FrontmatterResult {
    /// Parsed key-value fields from the YAML block
    let fields: [String: Any]
    /// Remaining markdown body after the frontmatter
    let body: String
}

/// Parses YAML frontmatter from markdown files.
/// Handles a simple YAML subset: scalar values, lists, and nested list-of-dicts (for quiz).
/// No external dependencies.
nonisolated enum FrontmatterParser {

    // MARK: - Public

    /// Parses a markdown string, extracting the `---`-delimited YAML frontmatter block.
    /// Returns `nil` if the input has no valid frontmatter (missing delimiters, malformed).
    static func parse(_ markdown: String) -> FrontmatterResult? {
        let lines = markdown.components(separatedBy: "\n")

        guard !lines.isEmpty, lines[0].trimmingCharacters(in: .whitespaces) == "---" else {
            return nil
        }

        // Find closing ---
        var closingIndex: Int?
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                closingIndex = i
                break
            }
        }

        guard let endIndex = closingIndex, endIndex > 1 else {
            return nil
        }

        let yamlLines = Array(lines[1..<endIndex])
        let bodyLines = Array(lines[(endIndex + 1)...])
        let body = bodyLines.joined(separator: "\n")

        let fields = parseYAML(yamlLines)
        return FrontmatterResult(fields: fields, body: body)
    }

    /// Convenience: parses frontmatter and maps fields to a `KnowledgeTopic`.
    /// Returns `nil` if required fields (id, title, summary) are missing.
    static func parseTopic(
        markdown: String,
        categoryId: String,
        contentPath: String
    ) -> (topic: KnowledgeTopic, body: String)? {
        guard let result = parse(markdown) else { return nil }
        let f = result.fields

        guard
            let id = f["id"] as? String,
            let title = f["title"] as? String,
            let summary = f["summary"] as? String
        else { return nil }

        let tags = (f["tags"] as? [String]) ?? []
        let level = (f["level"] as? String) ?? "Einsteiger"
        let readingMinutes = (f["reading_minutes"] as? String).flatMap { Int($0) } ?? 5
        let version = f["version"] as? String
        let relatedTopicIds = f["related"] as? [String]

        var quiz: [QuizQuestion]?
        if let quizDicts = f["quiz"] as? [[String: Any]] {
            quiz = quizDicts.compactMap { parseQuizQuestion($0) }
            if quiz?.isEmpty == true { quiz = nil }
        }

        let topic = KnowledgeTopic(
            id: id,
            title: title,
            summary: summary,
            categoryId: categoryId,
            tags: tags,
            level: level,
            readingMinutes: readingMinutes,
            version: version,
            lastUpdated: nil,
            quiz: quiz,
            relatedTopicIds: relatedTopicIds,
            contentPath: contentPath
        )

        return (topic, result.body)
    }

    // MARK: - YAML Parsing

    /// Parses a simple YAML subset from an array of lines.
    private static func parseYAML(_ lines: [String]) -> [String: Any] {
        var fields: [String: Any] = [:]
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Skip empty lines and comments
            if line.trimmingCharacters(in: .whitespaces).isEmpty ||
               line.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                i += 1
                continue
            }

            // Must be a top-level key: value line
            guard let colonRange = line.range(of: ":"),
                  !line.hasPrefix(" "),
                  !line.hasPrefix("\t") else {
                i += 1
                continue
            }

            let key = String(line[line.startIndex..<colonRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let rawValue = String(line[colonRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)

            if !rawValue.isEmpty {
                // Inline scalar value
                fields[key] = unquote(rawValue)
                i += 1
            } else {
                // Value is on subsequent indented lines — could be a list or nested structure
                i += 1
                let (value, nextIndex) = parseIndentedBlock(lines, startingAt: i)
                fields[key] = value
                i = nextIndex
            }
        }

        return fields
    }

    /// Parses an indented block starting at `startIndex`.
    /// Returns either a `[String]` (simple list) or `[[String: Any]]` (list of dicts).
    private static func parseIndentedBlock(
        _ lines: [String],
        startingAt startIndex: Int
    ) -> (Any, Int) {
        var i = startIndex
        var simpleItems: [String] = []
        var dictItems: [[String: Any]] = []
        var isNested = false

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // End of indented block — line is not indented
            guard line.hasPrefix(" ") || line.hasPrefix("\t") else {
                break
            }

            // Skip empty lines within block
            if trimmed.isEmpty {
                i += 1
                continue
            }

            if trimmed.hasPrefix("- ") {
                let itemContent = String(trimmed.dropFirst(2))

                // Check if this list item starts a nested dict (e.g., "- question: ...")
                if let colonRange = itemContent.range(of: ":"),
                   colonRange.lowerBound != itemContent.startIndex {
                    isNested = true
                    var dict: [String: Any] = [:]
                    let nestedKey = String(itemContent[itemContent.startIndex..<colonRange.lowerBound])
                        .trimmingCharacters(in: .whitespaces)
                    let nestedRawValue = String(itemContent[colonRange.upperBound...])
                        .trimmingCharacters(in: .whitespaces)

                    if !nestedRawValue.isEmpty {
                        dict[nestedKey] = unquote(nestedRawValue)
                    } else {
                        // Nested list under this dict key
                        i += 1
                        let (nestedValue, nextI) = parseNestedList(lines, startingAt: i)
                        dict[nestedKey] = nestedValue
                        i = nextI
                    }

                    // Continue reading sibling keys at same or deeper indent
                    i += (nestedRawValue.isEmpty ? 0 : 1)
                    while i < lines.count {
                        let subLine = lines[i]
                        let subTrimmed = subLine.trimmingCharacters(in: .whitespaces)

                        // Must be indented and not a new list item at same level
                        guard (subLine.hasPrefix("    ") || subLine.hasPrefix("\t\t") ||
                               subLine.hasPrefix("  ")) else { break }
                        guard !subTrimmed.hasPrefix("- ") || isMoreIndented(subLine, than: line) else { break }

                        if subTrimmed.isEmpty {
                            i += 1
                            continue
                        }

                        if subTrimmed.hasPrefix("- ") {
                            // Sub-list item for current dict key
                            i += 1
                            continue
                        }

                        // key: value pair within the dict
                        if let subColonRange = subTrimmed.range(of: ":") {
                            let subKey = String(subTrimmed[subTrimmed.startIndex..<subColonRange.lowerBound])
                                .trimmingCharacters(in: .whitespaces)
                            let subRaw = String(subTrimmed[subColonRange.upperBound...])
                                .trimmingCharacters(in: .whitespaces)

                            if !subRaw.isEmpty {
                                dict[subKey] = unquote(subRaw)
                            } else {
                                // Nested list value
                                i += 1
                                let (listValue, nextI) = parseNestedList(lines, startingAt: i)
                                dict[subKey] = listValue
                                i = nextI
                                continue
                            }
                        }
                        i += 1
                    }

                    dictItems.append(dict)
                } else {
                    // Simple list item
                    simpleItems.append(unquote(itemContent))
                    i += 1
                }
            } else {
                // Not a list item — stop
                break
            }
        }

        if isNested {
            return (dictItems, i)
        }
        return (simpleItems, i)
    }

    /// Parses a nested list of `- item` lines at deeper indentation.
    private static func parseNestedList(
        _ lines: [String],
        startingAt startIndex: Int
    ) -> ([String], Int) {
        var items: [String] = []
        var i = startIndex

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard (line.hasPrefix("    ") || line.hasPrefix("\t")) else { break }
            guard !trimmed.isEmpty else {
                i += 1
                continue
            }

            if trimmed.hasPrefix("- ") {
                items.append(unquote(String(trimmed.dropFirst(2))))
                i += 1
            } else {
                break
            }
        }

        return (items, i)
    }

    /// Checks if `lineA` has more leading whitespace than `lineB`.
    private static func isMoreIndented(_ lineA: String, than lineB: String) -> Bool {
        let indentA = lineA.prefix(while: { $0 == " " || $0 == "\t" }).count
        let indentB = lineB.prefix(while: { $0 == " " || $0 == "\t" }).count
        return indentA > indentB
    }

    /// Removes surrounding quotes from a string value.
    private static func unquote(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    // MARK: - Quiz Parsing

    /// Maps a parsed dict to a `QuizQuestion`.
    private static func parseQuizQuestion(_ dict: [String: Any]) -> QuizQuestion? {
        guard let question = dict["question"] as? String else { return nil }

        let options: [String]
        if let opts = dict["options"] as? [String] {
            options = opts
        } else {
            return nil
        }

        let correctIndex: Int
        if let correctStr = dict["correct"] as? String, let idx = Int(correctStr) {
            correctIndex = idx
        } else {
            correctIndex = 0
        }

        guard correctIndex >= 0, correctIndex < options.count else { return nil }

        return QuizQuestion(
            id: UUID(),
            question: question,
            options: options,
            correctAnswerIndex: correctIndex
        )
    }
}
