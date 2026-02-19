//
//  CalendarViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 19.02.26.
//

import Foundation
import Combine

/// Represents the current state of the calendar view.
enum CalendarLoadState: Equatable {
    /// Initial state, no data loaded yet
    case idle

    /// Currently loading events
    case loading

    /// Events loaded successfully (may be empty)
    case loaded

    /// Loading failed with an error message
    case error(message: String)
}

/// ViewModel for the Termine (Calendar) tab.
/// Coordinates between the CalendarView and the CalendarRepository.
@MainActor
final class CalendarViewModel: ObservableObject {

    // MARK: - Published State

    /// All events from the feed
    @Published private(set) var events: [CalendarEvent] = []

    /// The current load state
    @Published private(set) var loadState: CalendarLoadState = .idle

    // MARK: - Computed Properties

    /// Upcoming events (startDate >= now), sorted ascending by start date
    var upcomingEvents: [CalendarEvent] {
        let now = Date()
        return events
            .filter { $0.startDate >= now }
            .sorted { $0.startDate < $1.startDate }
    }

    /// Events from the past 7 days, sorted descending by start date
    var pastWeekEvents: [CalendarEvent] {
        let now = Date()
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        return events
            .filter { $0.startDate < now && $0.startDate >= oneWeekAgo }
            .sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Dependencies

    private let calendarRepository: CalendarRepository

    // MARK: - Initialization

    init(calendarRepository: CalendarRepository) {
        self.calendarRepository = calendarRepository
    }

    // MARK: - Public Methods

    /// Loads events from the repository.
    func loadEvents() {
        loadState = .loading

        Task {
            do {
                let fetchedEvents = try await calendarRepository.fetchEvents()
                self.events = fetchedEvents
                self.loadState = .loaded
            } catch let error as CalendarError {
                self.loadState = .error(message: error.localizedDescription)
            } catch {
                self.loadState = .error(message: "Ein unbekannter Fehler ist aufgetreten")
            }
        }
    }

    /// Refreshes the event list.
    func refresh() {
        loadEvents()
    }
}
