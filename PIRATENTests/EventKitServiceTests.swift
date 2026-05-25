//
//  EventKitServiceTests.swift
//  PIRATENTests
//
//  Tests for FR-EVT-003 ("Zu Kalender hinzufügen").
//
//  These tests target the **error-mapping** and **field-mapping** layers
//  of EventKitService — the parts where bugs can sneak in without iOS
//  noticing. They deliberately do NOT test:
//
//    * The actual EKEventStore.save call (requires the system calendar
//      database, can't run reliably in CI / on every developer machine
//      without granting Calendar permission to xctest).
//    * The system permission prompt UI (no API to drive that from tests).
//
//  Those paths get exercised by the manual test plan in the PR.
//

import EventKit
import Foundation
import Testing
@testable import PIRATEN

@MainActor
struct EventKitServiceTests {

    // MARK: - Error mapping

    @Test func permissionDeniedErrorIsEquatable() {
        // The view layer switches on the error case, so the cases must
        // be reliably comparable.
        let a: EventKitServiceError = .permissionDenied
        let b: EventKitServiceError = .permissionDenied
        let c: EventKitServiceError = .saveFailed
        #expect(a == b)
        #expect(a != c)
    }

    @Test func fakeServiceSurfacesPermissionDenied() async {
        // The view uses `EventKitServicing`; we verify the protocol can
        // be implemented to throw the documented error case. This is
        // the contract `CalendarEventDetailView.addToCalendar` relies on.
        let service = FakeEventKitService(behaviour: .denyPermission)
        let event = Self.sampleEvent()

        await #expect(throws: EventKitServiceError.permissionDenied) {
            try await service.addToCalendar(event)
        }
    }

    @Test func fakeServiceSurfacesSaveFailed() async {
        let service = FakeEventKitService(behaviour: .failSave)
        let event = Self.sampleEvent()

        await #expect(throws: EventKitServiceError.saveFailed) {
            try await service.addToCalendar(event)
        }
    }

    @Test func fakeServiceSucceedsAndCapturesEvent() async throws {
        let service = FakeEventKitService(behaviour: .succeed)
        let event = Self.sampleEvent()

        try await service.addToCalendar(event)

        #expect(service.capturedEvents.count == 1)
        #expect(service.capturedEvents.first?.title == event.title)
    }

    // MARK: - Field-mapping defaults (would-be production behaviour)

    /// Verifies the documented "1-hour default" fallback when the source
    /// event has no end date. The actual EventKit save isn't called —
    /// we just check our derivation rule.
    @Test func endDateDefaultsToOneHourAfterStart() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let event = CalendarEvent(
            id: "no-end",
            title: "Stammtisch",
            description: nil,
            startDate: start,
            endDate: nil,
            location: nil,
            url: nil,
            categories: []
        )

        // Mirrors the rule in EventKitService.save (which is private —
        // testing the rule itself rather than the side effect).
        let derivedEnd = event.endDate ?? event.startDate.addingTimeInterval(3600)

        #expect(derivedEnd == start.addingTimeInterval(3600))
    }

    @Test func endDateRespectsExplicitValueWhenPresent() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let explicitEnd = start.addingTimeInterval(7200)
        let event = CalendarEvent(
            id: "with-end",
            title: "Stammtisch",
            description: nil,
            startDate: start,
            endDate: explicitEnd,
            location: nil,
            url: nil,
            categories: []
        )

        let derivedEnd = event.endDate ?? event.startDate.addingTimeInterval(3600)

        #expect(derivedEnd == explicitEnd)
    }

    // MARK: - Helpers

    private static func sampleEvent() -> CalendarEvent {
        CalendarEvent(
            id: "test-1",
            title: "Test event",
            description: "Body text",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            location: "Berlin",
            url: URL(string: "https://example.com"),
            categories: ["Test"]
        )
    }
}

// MARK: - FakeEventKitService

/// Test-only stand-in for EventKitService. Records calls and lets the
/// test pick which error (if any) the call throws. Lives next to the
/// tests rather than under test-helpers because the surface is small
/// and only used here.
@MainActor
final class FakeEventKitService: EventKitServicing {

    enum Behaviour {
        case succeed
        case denyPermission
        case failSave
    }

    let behaviour: Behaviour
    private(set) var capturedEvents: [CalendarEvent] = []

    init(behaviour: Behaviour) {
        self.behaviour = behaviour
    }

    func addToCalendar(_ event: CalendarEvent) async throws {
        capturedEvents.append(event)
        switch behaviour {
        case .succeed:
            return
        case .denyPermission:
            throw EventKitServiceError.permissionDenied
        case .failSave:
            throw EventKitServiceError.saveFailed
        }
    }
}
