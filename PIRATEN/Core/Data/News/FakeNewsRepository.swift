//
//  FakeNewsRepository.swift
//  PIRATEN
//

import Foundation

/// Fake implementation of NewsRepository for previews and tests.
@MainActor
final class FakeNewsRepository: NewsRepository {

    var shouldThrow = false

    func fetchNews() async throws -> [NewsItem] {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        if shouldThrow {
            throw NewsAPIError.serverError(statusCode: 500)
        }

        return Self.sampleItems
    }

    static let sampleItems: [NewsItem] = [
        NewsItem(
            chatId: -1001,
            messageId: 1001,
            postedAt: Date().addingTimeInterval(-3600),
            text: "Einladung zum Bundesparteitag am 15. März 2026 in Berlin. Alle Mitglieder sind herzlich willkommen! Anmeldung ab sofort möglich."
        ),
        NewsItem(
            chatId: -1001,
            messageId: 1002,
            postedAt: Date().addingTimeInterval(-7200),
            text: "Neue Stellungnahme zum Digitale-Dienste-Gesetz veröffentlicht. Unsere Position zu Plattformregulierung und Meinungsfreiheit im Netz."
        ),
        NewsItem(
            chatId: -1001,
            messageId: 1003,
            postedAt: Date().addingTimeInterval(-86400),
            text: "Erfolg bei der Kommunalwahl in Hessen! Drei neue Mandate in Frankfurt und Kassel. Herzlichen Glückwunsch an alle Kandidat:innen!"
        ),
        NewsItem(
            chatId: -1001,
            messageId: 1004,
            postedAt: Date().addingTimeInterval(-172800),
            text: "Wer: AG Kommunalpolitik\nReminder: Morgen um 20 Uhr findet der wöchentliche Mumble-Stammtisch statt. Thema: Vorbereitung Wahlkampf 2026."
        ),
        NewsItem(
            chatId: -1001,
            messageId: 1005,
            postedAt: Date().addingTimeInterval(-259200),
            text: "Die AG Datenschutz hat ein neues Positionspapier zur Vorratsdatenspeicherung erarbeitet. Feedback willkommen!\n\nMehr Infos: https://wiki.piratenpartei.de/AG_Datenschutz"
        )
    ]
}
