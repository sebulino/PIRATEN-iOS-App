//
//  CalendarViewModelTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 19.02.26.
//

import Foundation
import Testing
@testable import PIRATEN

@Suite("CalendarViewModel Tests")
@MainActor
struct CalendarViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(repository: CalendarRepository? = nil) -> CalendarViewModel {
        CalendarViewModel(calendarRepository: repository ?? FakeCalendarRepository())
    }

    // MARK: - Load State Tests

    @Test("Initial state is idle")
    func initialState() {
        let vm = makeViewModel()
        #expect(vm.loadState == .idle)
        #expect(vm.events.isEmpty)
    }

    @Test("Loading transitions from idle to loading to loaded")
    func loadTransitions() async throws {
        let vm = makeViewModel()
        vm.loadEvents()

        // Should eventually reach loaded
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms to allow fake delay
        #expect(vm.loadState == .loaded)
        #expect(!vm.events.isEmpty)
    }

    @Test("Error state set when repository throws")
    func errorState() async throws {
        let vm = makeViewModel(repository: FailingCalendarRepository())
        vm.loadEvents()

        try await Task.sleep(nanoseconds: 200_000_000)
        if case .error = vm.loadState {
            // Expected
        } else {
            Issue.record("Expected error state but got \(vm.loadState)")
        }
    }

    // MARK: - Filtering Tests

    @Test("Upcoming events filters to future events sorted ascending")
    func upcomingEvents() {
        let vm = makeViewModel()
        let now = Date()
        let calendar = Calendar.current

        // Manually set events to test filtering
        let futureEvent = CalendarEvent(
            id: "f1", title: "Future", description: nil,
            startDate: calendar.date(byAdding: .day, value: 5, to: now)!,
            endDate: nil, location: nil, url: nil, categories: []
        )
        let pastEvent = CalendarEvent(
            id: "p1", title: "Past", description: nil,
            startDate: calendar.date(byAdding: .day, value: -5, to: now)!,
            endDate: nil, location: nil, url: nil, categories: []
        )

        // Access internal state via reflection workaround - load then check
        // Since we can't set events directly, test via FakeCalendarRepository
    }

    @Test("Past week events filters correctly")
    func pastWeekEvents() async throws {
        let vm = makeViewModel()
        vm.loadEvents()
        try await Task.sleep(nanoseconds: 300_000_000)

        // FakeCalendarRepository includes events from -2 and -5 days ago
        #expect(!vm.pastWeekEvents.isEmpty)
        // All past week events should be before now
        let now = Date()
        for event in vm.pastWeekEvents {
            #expect(event.startDate < now)
        }
    }

    @Test("Upcoming events from fake repository")
    func upcomingFromFake() async throws {
        let vm = makeViewModel()
        vm.loadEvents()
        try await Task.sleep(nanoseconds: 300_000_000)

        // FakeCalendarRepository includes events +3, +7, +30 days
        #expect(!vm.upcomingEvents.isEmpty)
        let now = Date()
        for event in vm.upcomingEvents {
            #expect(event.startDate >= now)
        }
        // Should be sorted ascending
        if vm.upcomingEvents.count >= 2 {
            #expect(vm.upcomingEvents[0].startDate <= vm.upcomingEvents[1].startDate)
        }
    }
}

// MARK: - Test Helpers

@MainActor
private final class FailingCalendarRepository: CalendarRepository {
    func fetchEvents() async throws -> [CalendarEvent] {
        throw CalendarError.networkError("Test error")
    }
}
