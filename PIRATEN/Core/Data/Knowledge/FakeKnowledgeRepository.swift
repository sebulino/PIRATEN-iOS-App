//
//  FakeKnowledgeRepository.swift
//  PIRATEN
//

import Foundation

/// Fake implementation of KnowledgeRepository for previews and tests.
/// Returns hardcoded sample data covering all section types.
@MainActor
final class FakeKnowledgeRepository: KnowledgeRepository {

    // MARK: - Sample Data

    private let sampleCategories: [KnowledgeCategory] = [
        KnowledgeCategory(
            id: "kommunalpolitik",
            title: "Kommunalpolitik",
            description: "Grundlagen und Praxis der politischen Arbeit in Gemeinden und Städten.",
            order: 1,
            icon: "building.2"
        ),
        KnowledgeCategory(
            id: "digitale-rechte",
            title: "Digitale Rechte",
            description: "Datenschutz, Netzneutralität und digitale Bürgerrechte.",
            order: 2,
            icon: "lock.shield"
        )
    ]

    private let sampleTopics: [KnowledgeTopic] = [
        KnowledgeTopic(
            id: "kommunalpolitik-grundlagen",
            title: "Grundlagen der Kommunalpolitik",
            summary: "Wie funktioniert politische Arbeit auf kommunaler Ebene? Ein Überblick über Strukturen, Gremien und Beteiligungsmöglichkeiten.",
            categoryId: "kommunalpolitik",
            tags: ["Gemeinderat", "Kommune", "Grundlagen"],
            level: "Einsteiger",
            readingMinutes: 8,
            version: "1.0",
            lastUpdated: nil,
            quiz: [
                QuizQuestion(
                    id: UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!,
                    question: "Welches Gremium ist das wichtigste Organ der Kommunalpolitik?",
                    options: ["Bundestag", "Gemeinderat", "Landtag", "Europaparlament"],
                    correctAnswerIndex: 1
                ),
                QuizQuestion(
                    id: UUID(uuidString: "B2C3D4E5-F6A7-8901-BCDE-F12345678901")!,
                    question: "Wie oft finden in der Regel Kommunalwahlen statt?",
                    options: ["Alle 2 Jahre", "Alle 4 Jahre", "Alle 5 Jahre", "Alle 6 Jahre"],
                    correctAnswerIndex: 2
                )
            ],
            relatedTopicIds: ["antraege-stellen"],
            contentPath: "kommunalpolitik/kommunalpolitik-grundlagen.md"
        ),
        KnowledgeTopic(
            id: "antraege-stellen",
            title: "Anträge stellen im Gemeinderat",
            summary: "Schritt-für-Schritt-Anleitung zum Einbringen von Anträgen in der Kommunalpolitik.",
            categoryId: "kommunalpolitik",
            tags: ["Antrag", "Gemeinderat", "Praxis"],
            level: "Fortgeschritten",
            readingMinutes: 12,
            version: "1.0",
            lastUpdated: nil,
            quiz: nil,
            relatedTopicIds: ["kommunalpolitik-grundlagen"],
            contentPath: "kommunalpolitik/antraege-stellen.md"
        ),
        KnowledgeTopic(
            id: "datenschutz-grundlagen",
            title: "Datenschutz-Grundlagen",
            summary: "Die wichtigsten Prinzipien des Datenschutzes und warum sie für die Piratenpartei zentral sind.",
            categoryId: "digitale-rechte",
            tags: ["DSGVO", "Datenschutz", "Grundlagen"],
            level: "Einsteiger",
            readingMinutes: 10,
            version: "1.0",
            lastUpdated: nil,
            quiz: nil,
            relatedTopicIds: ["netzneutralitaet"],
            contentPath: "digitale-rechte/datenschutz-grundlagen.md"
        ),
        KnowledgeTopic(
            id: "netzneutralitaet",
            title: "Netzneutralität verstehen",
            summary: "Was bedeutet Netzneutralität und warum ist sie ein Kernthema der Piraten?",
            categoryId: "digitale-rechte",
            tags: ["Netz", "Neutralität", "Internet"],
            level: "Einsteiger",
            readingMinutes: 6,
            version: "1.0",
            lastUpdated: nil,
            quiz: nil,
            relatedTopicIds: ["datenschutz-grundlagen"],
            contentPath: "digitale-rechte/netzneutralitaet.md"
        )
    ]

    private let sampleIndex: KnowledgeIndex

    private let sampleTopicContent: TopicContent

    // MARK: - Init

    init() {
        sampleIndex = KnowledgeIndex(
            categories: sampleCategories,
            topics: sampleTopics,
            featuredTopicIds: ["kommunalpolitik-grundlagen", "datenschutz-grundlagen"],
            learningPaths: [
                LearningPath(
                    id: "einstieg",
                    title: "Einstieg in die Parteiarbeit",
                    topicIds: ["kommunalpolitik-grundlagen", "antraege-stellen"]
                )
            ],
            lastFetched: Date(),
            etag: nil
        )

        let checklistId1 = UUID(uuidString: "C3D4E5F6-A7B8-9012-CDEF-123456789012")!
        let checklistId2 = UUID(uuidString: "D4E5F6A7-B8C9-0123-DEFA-234567890123")!
        let checklistId3 = UUID(uuidString: "E5F6A7B8-C9D0-1234-EFAB-345678901234")!

        sampleTopicContent = TopicContent(
            topicId: "kommunalpolitik-grundlagen",
            rawMarkdown: """
            ## Kurzüberblick
            - Kommunalpolitik betrifft das direkte Lebensumfeld
            - Der Gemeinderat ist das zentrale Entscheidungsgremium
            - Jede:r Bürger:in kann sich einbringen

            ## Was ist Kommunalpolitik?
            Kommunalpolitik umfasst alle politischen Entscheidungen auf der Ebene von Gemeinden, Städten und Landkreisen. Sie ist die politische Ebene, die den Alltag der Menschen am direktesten beeinflusst.

            > TIP: Kommunalpolitik ist der beste Einstieg in die aktive Parteiarbeit – hier siehst du direkte Ergebnisse deines Engagements.

            ## Strukturen und Gremien
            Der **Gemeinderat** (auch Stadtrat oder Stadtverordnetenversammlung) ist das wichtigste Gremium. Er wird von den Bürger:innen direkt gewählt und entscheidet über den Haushalt, Satzungen und kommunale Einrichtungen.

            > ACHTUNG: Die Bezeichnungen und Zuständigkeiten variieren je nach Bundesland erheblich.

            ## Checkliste
            - [ ] Informiere dich über deinen Gemeinderat
            - [ ] Besuche eine öffentliche Gemeinderatssitzung
            - [ ] Nimm Kontakt mit der lokalen Piratenfraktion auf

            > MERKSATZ: Kommunalpolitik ist die Basis der Demokratie – wer hier aktiv wird, gestaltet das direkte Lebensumfeld mit.

            ## Nächste Schritte
            - antraege-stellen
            """,
            sections: [
                .overview([
                    "Kommunalpolitik betrifft das direkte Lebensumfeld",
                    "Der Gemeinderat ist das zentrale Entscheidungsgremium",
                    "Jede:r Bürger:in kann sich einbringen"
                ]),
                .text(
                    heading: "Was ist Kommunalpolitik?",
                    body: "Kommunalpolitik umfasst alle politischen Entscheidungen auf der Ebene von Gemeinden, Städten und Landkreisen. Sie ist die politische Ebene, die den Alltag der Menschen am direktesten beeinflusst."
                ),
                .callout(.tip, "Kommunalpolitik ist der beste Einstieg in die aktive Parteiarbeit – hier siehst du direkte Ergebnisse deines Engagements."),
                .text(
                    heading: "Strukturen und Gremien",
                    body: "Der **Gemeinderat** (auch Stadtrat oder Stadtverordnetenversammlung) ist das wichtigste Gremium. Er wird von den Bürger:innen direkt gewählt und entscheidet über den Haushalt, Satzungen und kommunale Einrichtungen."
                ),
                .callout(.warning, "Die Bezeichnungen und Zuständigkeiten variieren je nach Bundesland erheblich."),
                .checklist([
                    ChecklistItem(id: checklistId1, text: "Informiere dich über deinen Gemeinderat"),
                    ChecklistItem(id: checklistId2, text: "Besuche eine öffentliche Gemeinderatssitzung"),
                    ChecklistItem(id: checklistId3, text: "Nimm Kontakt mit der lokalen Piratenfraktion auf")
                ]),
                .callout(.keyTakeaway, "Kommunalpolitik ist die Basis der Demokratie – wer hier aktiv wird, gestaltet das direkte Lebensumfeld mit."),
                .quiz([
                    QuizQuestion(
                        id: UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!,
                        question: "Welches Gremium ist das wichtigste Organ der Kommunalpolitik?",
                        options: ["Bundestag", "Gemeinderat", "Landtag", "Europaparlament"],
                        correctAnswerIndex: 1
                    ),
                    QuizQuestion(
                        id: UUID(uuidString: "B2C3D4E5-F6A7-8901-BCDE-F12345678901")!,
                        question: "Wie oft finden in der Regel Kommunalwahlen statt?",
                        options: ["Alle 2 Jahre", "Alle 4 Jahre", "Alle 5 Jahre", "Alle 6 Jahre"],
                        correctAnswerIndex: 2
                    )
                ]),
                .nextSteps(["antraege-stellen"])
            ]
        )
    }

    // MARK: - KnowledgeRepository

    func fetchIndex(forceRefresh: Bool) async throws -> KnowledgeIndex {
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
        return sampleIndex
    }

    func fetchTopicContent(topicId: String) async throws -> TopicContent {
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay

        // Return sample content for the known topic, throw notFound for others
        guard topicId == sampleTopicContent.topicId else {
            throw KnowledgeError.notFound
        }
        return sampleTopicContent
    }
}
