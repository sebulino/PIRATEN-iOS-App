//
//  FakeNewsRepository.swift
//  PIRATEN
//

import Foundation

/// Fake implementation of NewsRepository for previews and tests.
@MainActor
final class FakeNewsRepository: NewsRepository {

    var shouldThrow = false

    func fetchNews() async throws -> [NewsPost] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        if shouldThrow {
            throw TelegramError.apiError(statusCode: 500)
        }

        return Self.samplePosts
    }

    static let samplePosts: [NewsPost] = [
        NewsPost(
            id: 1001,
            text: "Einladung zum Bundesparteitag am 15. März 2026 in Berlin. Alle Mitglieder sind herzlich willkommen! Anmeldung ab sofort möglich.",
            date: Date().addingTimeInterval(-3600),
            authorName: "Piraten News Bot"
        ),
        NewsPost(
            id: 1002,
            text: "Neue Stellungnahme zum Digitale-Dienste-Gesetz veröffentlicht. Unsere Position zu Plattformregulierung und Meinungsfreiheit im Netz.",
            date: Date().addingTimeInterval(-7200),
            authorName: "Piraten News Bot"
        ),
        NewsPost(
            id: 1003,
            text: "Erfolg bei der Kommunalwahl in Hessen! Drei neue Mandate in Frankfurt und Kassel. Herzlichen Glückwunsch an alle Kandidat:innen!",
            date: Date().addingTimeInterval(-86400),
            authorName: "Piraten News Bot"
        ),
        NewsPost(
            id: 1004,
            text: "Reminder: Morgen um 20 Uhr findet der wöchentliche Mumble-Stammtisch statt. Thema: Vorbereitung Wahlkampf 2026.",
            date: Date().addingTimeInterval(-172800),
            authorName: "Piraten News Bot"
        ),
        NewsPost(
            id: 1005,
            text: "Die AG Datenschutz hat ein neues Positionspapier zur Vorratsdatenspeicherung erarbeitet. Feedback willkommen!",
            date: Date().addingTimeInterval(-259200),
            authorName: "AG Datenschutz"
        )
    ]
}
