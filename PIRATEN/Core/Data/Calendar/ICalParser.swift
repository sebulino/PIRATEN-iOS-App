//
//  ICalParser.swift
//  PIRATEN
//
//  Created by Claude Code on 19.02.26.
//

import Foundation

/// Lightweight parser for iCalendar (RFC 5545) VCALENDAR/VEVENT data.
///
/// Handles:
/// - BEGIN:VEVENT / END:VEVENT block extraction
/// - Key-value line parsing including KEY;PARAM=X:VALUE format
/// - DTSTART/DTEND in yyyyMMdd'T'HHmmss and yyyyMMdd formats (with optional Z suffix)
/// - RFC 5545 line unfolding (continuation lines starting with space or tab)
/// - Graceful skipping of unparseable events
struct ICalParser {

    // MARK: - Date Formatters

    /// Parses date-time strings like 20260315T140000 or 20260315T140000Z
    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd'T'HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        return f
    }()

    /// Parses date-only strings like 20260315
    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        return f
    }()

    /// UTC date-time formatter for Z-suffix dates
    private static let utcDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd'T'HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(abbreviation: "UTC")
        return f
    }()

    // MARK: - Public API

    /// Parses iCalendar text data into an array of CalendarEvent objects.
    /// Events that cannot be parsed (missing UID or DTSTART) are silently skipped.
    /// - Parameter data: Raw iCal text data
    /// - Returns: Array of successfully parsed events
    func parse(_ data: String) -> [CalendarEvent] {
        let unfolded = unfoldLines(data)
        let eventBlocks = extractEventBlocks(from: unfolded)

        return eventBlocks.compactMap { block in
            parseEvent(from: block)
        }
    }

    // MARK: - Private Helpers

    /// RFC 5545 line unfolding: lines starting with a space or tab are continuations.
    private func unfoldLines(_ text: String) -> String {
        // Replace CRLF + space/tab with empty string (join continuation lines)
        var result = text.replacingOccurrences(of: "\r\n ", with: "")
        result = result.replacingOccurrences(of: "\r\n\t", with: "")
        // Also handle LF-only line endings
        result = result.replacingOccurrences(of: "\n ", with: "")
        result = result.replacingOccurrences(of: "\n\t", with: "")
        return result
    }

    /// Extracts VEVENT blocks as arrays of lines.
    private func extractEventBlocks(from text: String) -> [[String]] {
        let lines = text.components(separatedBy: .newlines)
        var blocks: [[String]] = []
        var currentBlock: [String]?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased() == "BEGIN:VEVENT" {
                currentBlock = []
            } else if trimmed.uppercased() == "END:VEVENT" {
                if let block = currentBlock {
                    blocks.append(block)
                }
                currentBlock = nil
            } else if currentBlock != nil {
                currentBlock?.append(line)
            }
        }

        return blocks
    }

    /// Parses a single VEVENT block into a CalendarEvent.
    /// Returns nil if required fields (UID, DTSTART) are missing.
    private func parseEvent(from lines: [String]) -> CalendarEvent? {
        var properties: [String: String] = [:]

        for line in lines {
            guard let (key, value) = parseLine(line) else { continue }
            // Use the base key name (strip parameters like DTSTART;VALUE=DATE)
            let baseKey = key.components(separatedBy: ";").first?.uppercased() ?? key.uppercased()
            // Keep original full key for parameter extraction
            if baseKey == "DTSTART" || baseKey == "DTEND" {
                properties[baseKey] = value
                // Store the full key to detect VALUE=DATE parameter
                properties[baseKey + "_FULLKEY"] = key
            } else {
                properties[baseKey] = value
            }
        }

        // Required fields
        guard let uid = properties["UID"],
              let startString = properties["DTSTART"],
              let startDate = parseDate(startString, fullKey: properties["DTSTART_FULLKEY"]) else {
            return nil
        }

        // Optional SUMMARY - use UID as fallback title
        let title = properties["SUMMARY"]?.unescapingICalText() ?? uid

        let endDate: Date?
        if let endString = properties["DTEND"] {
            endDate = parseDate(endString, fullKey: properties["DTEND_FULLKEY"])
        } else {
            endDate = nil
        }

        let categories: [String]
        if let catString = properties["CATEGORIES"] {
            categories = catString.components(separatedBy: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
        } else {
            categories = []
        }

        let eventURL: URL?
        if let urlString = properties["URL"] {
            eventURL = URL(string: urlString)
        } else {
            eventURL = nil
        }

        return CalendarEvent(
            id: uid,
            title: title,
            description: properties["DESCRIPTION"]?.unescapingICalText(),
            startDate: startDate,
            endDate: endDate,
            location: properties["LOCATION"]?.unescapingICalText(),
            url: eventURL,
            categories: categories
        )
    }

    /// Parses a single iCal property line into key-value pair.
    /// Handles KEY:VALUE and KEY;PARAM=X:VALUE formats.
    private func parseLine(_ line: String) -> (key: String, value: String)? {
        // Find the first colon that separates key from value
        // But the key part may contain semicolons (parameters)
        guard let colonIndex = line.firstIndex(of: ":") else { return nil }
        let key = String(line[line.startIndex..<colonIndex])
        let value = String(line[line.index(after: colonIndex)...])
        guard !key.isEmpty else { return nil }
        return (key, value)
    }

    /// Parses a date string in various iCal formats.
    private func parseDate(_ string: String, fullKey: String?) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)

        // Check for VALUE=DATE parameter (date-only format)
        let isDateOnly = fullKey?.uppercased().contains("VALUE=DATE") == true
            && !(fullKey?.uppercased().contains("VALUE=DATE-TIME") == true)

        if isDateOnly || trimmed.count == 8 {
            return Self.dateOnlyFormatter.date(from: trimmed)
        }

        // Z suffix means UTC
        if trimmed.hasSuffix("Z") {
            let withoutZ = String(trimmed.dropLast())
            return Self.utcDateTimeFormatter.date(from: withoutZ)
        }

        return Self.dateTimeFormatter.date(from: trimmed)
    }
}

// MARK: - String Extension for iCal Text Unescaping

private extension String {
    /// Unescapes iCal text values per RFC 5545.
    /// Handles \\n → newline, \\, → comma, \\\\ → backslash.
    func unescapingICalText() -> String {
        var result = self
        result = result.replacingOccurrences(of: "\\n", with: "\n")
        result = result.replacingOccurrences(of: "\\N", with: "\n")
        result = result.replacingOccurrences(of: "\\,", with: ",")
        result = result.replacingOccurrences(of: "\\;", with: ";")
        result = result.replacingOccurrences(of: "\\\\", with: "\\")
        return result
    }
}
