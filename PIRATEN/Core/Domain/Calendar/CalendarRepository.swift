//
//  CalendarRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 19.02.26.
//

import Foundation

/// Errors that can occur when fetching calendar events.
enum CalendarError: Error, Equatable {
    /// Network request failed
    case networkError(String)

    /// iCal data could not be parsed
    case parsingError(String)

    var localizedDescription: String {
        switch self {
        case .networkError(let message):
            return "Netzwerkfehler: \(message)"
        case .parsingError(let message):
            return "Kalender konnte nicht gelesen werden: \(message)"
        }
    }
}

/// Repository for fetching calendar events from the piragitator.de iCal feed.
/// The endpoint is public and does not require authentication.
@MainActor
protocol CalendarRepository {
    /// Fetches all events from the iCal feed.
    /// - Returns: Array of calendar events
    /// - Throws: CalendarError if fetch or parsing fails
    func fetchEvents() async throws -> [CalendarEvent]
}
