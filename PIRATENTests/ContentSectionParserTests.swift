//
//  ContentSectionParserTests.swift
//  PIRATENTests
//

import Testing
@testable import PIRATEN

struct ContentSectionParserTests {

    // MARK: - H2 Splitting

    @Test func splitByH2Headings() {
        let body = """
        ## First Section
        Content of first section.

        ## Second Section
        Content of second section.
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 2)
        if case .text(let heading, let body) = sections[0] {
            #expect(heading == "First Section")
            #expect(body.contains("Content of first section"))
        } else {
            Issue.record("Expected .text section")
        }
        if case .text(let heading, _) = sections[1] {
            #expect(heading == "Second Section")
        } else {
            Issue.record("Expected .text section")
        }
    }

    @Test func contentBeforeFirstH2() {
        let body = """
        Some intro text before any heading.

        ## First Section
        Section content.
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 2)
        // First section has no heading — treated as text with empty heading
        if case .text(let heading, let content) = sections[0] {
            #expect(heading == "")
            #expect(content.contains("Some intro text"))
        } else {
            Issue.record("Expected .text section for pre-H2 content")
        }
    }

    @Test func noH2sEntireBodyAsSingleSection() {
        let body = """
        Just some plain text without any headings.
        Multiple lines of content.
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 1)
        if case .text(let heading, _) = sections[0] {
            #expect(heading == "")
        } else {
            Issue.record("Expected .text section")
        }
    }

    @Test func emptyBody() {
        let sections = ContentSectionParser.parse("")
        #expect(sections.isEmpty)
    }

    @Test func onlyWhitespace() {
        let sections = ContentSectionParser.parse("   \n\n   ")
        #expect(sections.isEmpty)
    }

    // MARK: - Special Section Types

    @Test func overviewSection() {
        let body = """
        ## Kurzüberblick
        - Punkt eins
        - Punkt zwei
        - Punkt drei
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 1)
        if case .overview(let bullets) = sections[0] {
            #expect(bullets == ["Punkt eins", "Punkt zwei", "Punkt drei"])
        } else {
            Issue.record("Expected .overview section")
        }
    }

    @Test func overviewWithAsteriskBullets() {
        let body = """
        ## Kurzüberblick
        * Item A
        * Item B
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 1)
        if case .overview(let bullets) = sections[0] {
            #expect(bullets == ["Item A", "Item B"])
        } else {
            Issue.record("Expected .overview section")
        }
    }

    @Test func overviewNoBulletsFallback() {
        let body = """
        ## Kurzüberblick
        Just a paragraph without bullets.
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 1)
        if case .overview(let bullets) = sections[0] {
            #expect(bullets.count == 1)
            #expect(bullets[0].contains("Just a paragraph"))
        } else {
            Issue.record("Expected .overview section")
        }
    }

    @Test func checklistSection() {
        let body = """
        ## Checkliste
        - [ ] First task
        - [x] Completed task
        - [ ] Third task
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 1)
        if case .checklist(let items) = sections[0] {
            #expect(items.count == 3)
            #expect(items[0].text == "First task")
            #expect(items[1].text == "Completed task")
            #expect(items[2].text == "Third task")
        } else {
            Issue.record("Expected .checklist section")
        }
    }

    @Test func checklistWithUppercaseX() {
        let body = """
        ## Checkliste
        - [X] Done task
        - [ ] Undone task
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 1)
        if case .checklist(let items) = sections[0] {
            #expect(items.count == 2)
            #expect(items[0].text == "Done task")
        } else {
            Issue.record("Expected .checklist section")
        }
    }

    @Test func nextStepsSection() {
        let body = """
        ## Nächste Schritte
        - Kommunalpolitik-Grundlagen lesen
        - Wahlrecht vertiefen
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 1)
        if case .nextSteps(let steps) = sections[0] {
            #expect(steps.count == 2)
            #expect(steps[0] == "Kommunalpolitik-Grundlagen lesen")
        } else {
            Issue.record("Expected .nextSteps section")
        }
    }

    @Test func miniQuizSkipped() {
        let body = """
        ## Mini-Quiz
        This content should be skipped entirely.

        ## After Quiz
        This should be kept.
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 1)
        if case .text(let heading, _) = sections[0] {
            #expect(heading == "After Quiz")
        } else {
            Issue.record("Expected .text section after skipped quiz")
        }
    }

    // MARK: - Callout Detection

    @Test func tipCallout() {
        let body = """
        ## Tipp
        > TIP: This is a helpful tip
        > that spans multiple lines.
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 1)
        if case .callout(let type, let text) = sections[0] {
            #expect(type == .tip)
            #expect(text.contains("This is a helpful tip"))
        } else {
            Issue.record("Expected .callout section, got \(sections[0])")
        }
    }

    @Test func warningCallout() {
        let body = """
        ## Warnung
        > ACHTUNG: Be careful with this!
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 1)
        if case .callout(let type, let text) = sections[0] {
            #expect(type == .warning)
            #expect(text.contains("Be careful"))
        } else {
            Issue.record("Expected .callout section")
        }
    }

    @Test func keyTakeawayCallout() {
        let body = """
        ## Merke
        > MERKSATZ: This is important to remember.
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 1)
        if case .callout(let type, let text) = sections[0] {
            #expect(type == .keyTakeaway)
            #expect(text.contains("important to remember"))
        } else {
            Issue.record("Expected .callout section")
        }
    }

    @Test func nonCalloutBlockquoteRemainsText() {
        let body = """
        ## Quote
        > Just a regular quote without a callout prefix.
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 1)
        // Regular blockquote without callout prefix stays as .text
        if case .text(let heading, _) = sections[0] {
            #expect(heading == "Quote")
        } else if case .callout(_, _) = sections[0] {
            Issue.record("Should not be a callout without recognized prefix")
        }
    }

    @Test func mixedBlockquoteAndTextStaysAsText() {
        let body = """
        ## Mixed
        Some text before.
        > TIP: A tip here.
        Some text after.
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 1)
        // Mixed content with non-quote lines stays as .text
        if case .text(let heading, _) = sections[0] {
            #expect(heading == "Mixed")
        } else {
            Issue.record("Expected .text for mixed content")
        }
    }

    // MARK: - Edge Cases

    @Test func emptySectionBetweenH2s() {
        let body = """
        ## Empty Section

        ## Non-Empty Section
        Some content here.
        """

        let sections = ContentSectionParser.parse(body)
        // Empty section should still be included as .text with empty body
        let nonEmpty = sections.filter {
            if case .text(_, let b) = $0 { return !b.isEmpty }
            return true
        }
        #expect(nonEmpty.count >= 1)
    }

    @Test func multipleSectionTypes() {
        let body = """
        ## Kurzüberblick
        - Punkt A
        - Punkt B

        ## Grundlagen
        Hier steht der Haupttext.

        ## Checkliste
        - [ ] Task 1
        - [ ] Task 2

        ## Nächste Schritte
        - Weiter zu Thema X
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 4)

        if case .overview(let bullets) = sections[0] {
            #expect(bullets.count == 2)
        } else {
            Issue.record("Expected .overview")
        }

        if case .text(let heading, _) = sections[1] {
            #expect(heading == "Grundlagen")
        } else {
            Issue.record("Expected .text")
        }

        if case .checklist(let items) = sections[2] {
            #expect(items.count == 2)
        } else {
            Issue.record("Expected .checklist")
        }

        if case .nextSteps(let steps) = sections[3] {
            #expect(steps.count == 1)
        } else {
            Issue.record("Expected .nextSteps")
        }
    }

    @Test func preservesSectionOrder() {
        let body = """
        ## Nächste Schritte
        - Step 1

        ## Kurzüberblick
        - Overview point

        ## Checkliste
        - [ ] Task
        """

        let sections = ContentSectionParser.parse(body)
        #expect(sections.count == 3)
        // Verify order is preserved (not reordered by type)
        if case .nextSteps(_) = sections[0] { } else {
            Issue.record("First should be nextSteps")
        }
        if case .overview(_) = sections[1] { } else {
            Issue.record("Second should be overview")
        }
        if case .checklist(_) = sections[2] { } else {
            Issue.record("Third should be checklist")
        }
    }
}
