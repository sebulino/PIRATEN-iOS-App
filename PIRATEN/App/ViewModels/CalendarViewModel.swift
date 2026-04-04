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

    /// Whether there are new events since the user last viewed the Termine tab
    @Published private(set) var hasNewContent: Bool = false

    private static let lastSeenEventCountKey = "calendar_last_seen_event_count"

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

    /// Timer for periodic background polling (every 5 minutes)
    private var pollingTimer: Timer?

    /// Polling interval in seconds (5 minutes)
    private static let pollingInterval: TimeInterval = 300

    // MARK: - Initialization

    init(calendarRepository: CalendarRepository) {
        self.calendarRepository = calendarRepository
        startPolling()
    }

    deinit {
        pollingTimer?.invalidate()
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
                self.updateNewContentFlag()
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

    /// Marks the Termine tab as viewed, clearing the new content indicator.
    func markAsViewed() {
        let count = upcomingEvents.count
        UserDefaults.standard.set(count, forKey: Self.lastSeenEventCountKey)
        hasNewContent = false
    }

    // MARK: - Private Helpers

    private func updateNewContentFlag() {
        let currentCount = upcomingEvents.count
        let lastSeenCount = UserDefaults.standard.integer(forKey: Self.lastSeenEventCountKey)
        // Show as new if we have events and the count changed since last viewed
        hasNewContent = lastSeenCount != 0 && currentCount != lastSeenCount
    }

    // MARK: - Polling

    /// Starts a repeating timer that polls for new events every 5 minutes.
    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: Self.pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollForNewContent()
            }
        }
    }

    /// Fetches events in the background and updates the new-content badge
    /// without disrupting the current view.
    private func pollForNewContent() async {
        do {
            let fetchedEvents = try await calendarRepository.fetchEvents()
            // Only update the badge flag; don't replace the displayed list
            // unless the user hasn't loaded anything yet
            if events.isEmpty {
                events = fetchedEvents
                loadState = .loaded
            }
            let currentCount = fetchedEvents.filter { $0.startDate >= Date() }.count
            let lastSeenCount = UserDefaults.standard.integer(forKey: Self.lastSeenEventCountKey)
            hasNewContent = lastSeenCount != 0 && currentCount != lastSeenCount
        } catch {
            // Polling failures are silent — don't disturb the user
        }
    }
}
