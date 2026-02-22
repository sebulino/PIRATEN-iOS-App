//
//  RealCalendarRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 19.02.26.
//

import Foundation

/// Production implementation of CalendarRepository.
/// Fetches iCal data from piragitator.de and parses it into CalendarEvent objects.
@MainActor
final class RealCalendarRepository: CalendarRepository {

    // MARK: - Dependencies

    private let apiClient: CalendarAPIClient
    private let parser: ICalParser

    // MARK: - Initialization

    init(apiClient: CalendarAPIClient, parser: ICalParser) {
        self.apiClient = apiClient
        self.parser = parser
    }

    // MARK: - CalendarRepository

    func fetchEvents() async throws -> [CalendarEvent] {
        let icalText = try await apiClient.fetchICalData()
        let events = parser.parse(icalText)

        if events.isEmpty && !icalText.isEmpty {
            throw CalendarError.parsingError("Keine Termine im Kalender gefunden")
        }

        return events
    }
}
