//
//  FakeCalendarRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 19.02.26.
//

import Foundation

/// Fake implementation of CalendarRepository for previews and tests.
/// Returns hardcoded sample events without network access.
@MainActor
final class FakeCalendarRepository: CalendarRepository {

    // MARK: - CalendarRepository

    func fetchEvents() async throws -> [CalendarEvent] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        let now = Date()
        let calendar = Calendar.current

        return [
            CalendarEvent(
                id: "event-1",
                title: "Landesparteitag NRW",
                description: "Ordentlicher Landesparteitag der Piratenpartei NRW",
                startDate: calendar.date(byAdding: .day, value: 7, to: now)!,
                endDate: calendar.date(byAdding: .day, value: 8, to: now)!,
                location: "Dortmund, Westfalenhalle",
                url: URL(string: "https://piragitator.de/veranstaltung/1/"),
                categories: ["Parteitag"]
            ),
            CalendarEvent(
                id: "event-2",
                title: "AG Digitalisierung - Stammtisch",
                description: "Monatliches Treffen der AG Digitalisierung",
                startDate: calendar.date(byAdding: .day, value: 3, to: now)!,
                endDate: calendar.date(byAdding: .hour, value: 2, to: calendar.date(byAdding: .day, value: 3, to: now)!)!,
                location: "Online (Jitsi)",
                url: nil,
                categories: ["AG", "Stammtisch"]
            ),
            CalendarEvent(
                id: "event-3",
                title: "Kreisverband Berlin - Vorstandssitzung",
                description: nil,
                startDate: calendar.date(byAdding: .day, value: -2, to: now)!,
                endDate: nil,
                location: "Berlin, Landesgeschäftsstelle",
                url: nil,
                categories: ["Vorstand"]
            ),
            CalendarEvent(
                id: "event-4",
                title: "Bundesparteitag",
                description: "Ordentlicher Bundesparteitag der Piratenpartei Deutschland",
                startDate: calendar.date(byAdding: .day, value: 30, to: now)!,
                endDate: calendar.date(byAdding: .day, value: 31, to: now)!,
                location: "Kassel, Kongress Palais",
                url: URL(string: "https://piragitator.de/veranstaltung/4/"),
                categories: ["Parteitag", "Bund"]
            ),
            CalendarEvent(
                id: "event-5",
                title: "Politischer Stammtisch Köln",
                description: "Offener Stammtisch für alle Interessierten",
                startDate: calendar.date(byAdding: .day, value: -5, to: now)!,
                endDate: nil,
                location: "Köln, Café Central",
                url: nil,
                categories: ["Stammtisch"]
            ),
        ]
    }
}
