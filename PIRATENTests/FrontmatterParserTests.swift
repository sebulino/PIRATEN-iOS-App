//
//  FrontmatterParserTests.swift
//  PIRATENTests
//

import Testing
@testable import PIRATEN

struct FrontmatterParserTests {

    // MARK: - Valid Frontmatter

    @Test func parseValidFrontmatter() {
        let markdown = """
        ---
        id: test-topic
        title: Test Topic
        summary: A short summary
        ---
        # Body content
        Some text here.
        """

        let result = FrontmatterParser.parse(markdown)
        #expect(result != nil)
        #expect(result?.fields["id"] as? String == "test-topic")
        #expect(result?.fields["title"] as? String == "Test Topic")
        #expect(result?.fields["summary"] as? String == "A short summary")
        #expect(result?.body.contains("Body content") == true)
    }

    @Test func parseQuotedValues() {
        let markdown = """
        ---
        title: "Quoted Title"
        summary: 'Single Quoted'
        ---
        Body
        """

        let result = FrontmatterParser.parse(markdown)
        #expect(result != nil)
        #expect(result?.fields["title"] as? String == "Quoted Title")
        #expect(result?.fields["summary"] as? String == "Single Quoted")
    }

    @Test func parseListFields() {
        let markdown = """
        ---
        id: test
        title: Test
        summary: Summary
        tags:
          - Bundestag
          - Wahlrecht
          - Politik
        related:
          - topic-a
          - topic-b
        ---
        Body
        """

        let result = FrontmatterParser.parse(markdown)
        #expect(result != nil)
        let tags = result?.fields["tags"] as? [String]
        #expect(tags == ["Bundestag", "Wahlrecht", "Politik"])
        let related = result?.fields["related"] as? [String]
        #expect(related == ["topic-a", "topic-b"])
    }

    @Test func parseQuizFields() {
        let markdown = """
        ---
        id: quiz-topic
        title: Quiz Topic
        summary: A topic with quiz
        quiz:
          - question: "What is 1+1?"
            options:
              - "1"
              - "2"
              - "3"
            correct: 1
          - question: "What color is the sky?"
            options:
              - "Red"
              - "Blue"
            correct: 1
        ---
        Body
        """

        let result = FrontmatterParser.parse(markdown)
        #expect(result != nil)
        let quizDicts = result?.fields["quiz"] as? [[String: Any]]
        #expect(quizDicts != nil)
        #expect(quizDicts?.count == 2)
        #expect(quizDicts?[0]["question"] as? String == "What is 1+1?")
        let options = quizDicts?[0]["options"] as? [String]
        #expect(options == ["1", "2", "3"])
        #expect(quizDicts?[0]["correct"] as? String == "1")
    }

    @Test func parseAllKnownFields() {
        let markdown = """
        ---
        id: full-topic
        title: Full Topic
        summary: Complete example
        level: Fortgeschritten
        reading_minutes: 10
        version: 2.0
        tags:
          - Tag1
          - Tag2
        ---
        Body content
        """

        let result = FrontmatterParser.parse(markdown)
        #expect(result != nil)
        #expect(result?.fields["id"] as? String == "full-topic")
        #expect(result?.fields["level"] as? String == "Fortgeschritten")
        #expect(result?.fields["reading_minutes"] as? String == "10")
        #expect(result?.fields["version"] as? String == "2.0")
    }

    // MARK: - Malformed / Missing Frontmatter

    @Test func parseMissingOpeningDelimiter() {
        let markdown = """
        id: test
        title: Test
        ---
        Body
        """

        let result = FrontmatterParser.parse(markdown)
        #expect(result == nil)
    }

    @Test func parseMissingClosingDelimiter() {
        let markdown = """
        ---
        id: test
        title: Test
        Body without closing delimiter
        """

        let result = FrontmatterParser.parse(markdown)
        #expect(result == nil)
    }

    @Test func parseEmptyFrontmatter() {
        let markdown = """
        ---
        ---
        Body
        """

        // Empty frontmatter block (endIndex == 1, not > 1)
        let result = FrontmatterParser.parse(markdown)
        #expect(result == nil)
    }

    @Test func parseEmptyInput() {
        let result = FrontmatterParser.parse("")
        #expect(result == nil)
    }

    @Test func parseNoFrontmatter() {
        let markdown = """
        # Just a heading
        Some regular markdown without frontmatter.
        """

        let result = FrontmatterParser.parse(markdown)
        #expect(result == nil)
    }

    @Test func parseBodyPreservation() {
        let markdown = """
        ---
        id: test
        ---
        Line 1
        Line 2
        Line 3
        """

        let result = FrontmatterParser.parse(markdown)
        #expect(result != nil)
        #expect(result?.body.contains("Line 1") == true)
        #expect(result?.body.contains("Line 2") == true)
        #expect(result?.body.contains("Line 3") == true)
    }

    // MARK: - parseTopic

    @Test func parseTopicValid() {
        let markdown = """
        ---
        id: bundestagswahl
        title: Bundestagswahl
        summary: Alles zur Bundestagswahl
        level: Einsteiger
        reading_minutes: 8
        tags:
          - Bundestag
          - Wahl
        ---
        ## Kurzüberblick
        - Punkt 1
        - Punkt 2
        """

        let result = FrontmatterParser.parseTopic(
            markdown: markdown,
            categoryId: "politik",
            contentPath: "politik/bundestagswahl.md"
        )

        #expect(result != nil)
        let topic = result!.topic
        #expect(topic.id == "bundestagswahl")
        #expect(topic.title == "Bundestagswahl")
        #expect(topic.summary == "Alles zur Bundestagswahl")
        #expect(topic.categoryId == "politik")
        #expect(topic.level == "Einsteiger")
        #expect(topic.readingMinutes == 8)
        #expect(topic.tags == ["Bundestag", "Wahl"])
        #expect(topic.contentPath == "politik/bundestagswahl.md")
        #expect(result!.body.contains("Kurzüberblick") == true)
    }

    @Test func parseTopicMissingRequiredFields() {
        let markdown = """
        ---
        id: test
        title: Test
        ---
        Body
        """

        // Missing `summary` — should return nil
        let result = FrontmatterParser.parseTopic(
            markdown: markdown,
            categoryId: "cat",
            contentPath: "cat/test.md"
        )
        #expect(result == nil)
    }

    @Test func parseTopicDefaultValues() {
        let markdown = """
        ---
        id: defaults
        title: Default Test
        summary: Testing defaults
        ---
        Body
        """

        let result = FrontmatterParser.parseTopic(
            markdown: markdown,
            categoryId: "cat",
            contentPath: "cat/defaults.md"
        )

        #expect(result != nil)
        let topic = result!.topic
        #expect(topic.level == "Einsteiger")  // default
        #expect(topic.readingMinutes == 5)  // default
        #expect(topic.tags.isEmpty)
        #expect(topic.version == nil)
        #expect(topic.quiz == nil)
        #expect(topic.relatedTopicIds == nil)
    }

    @Test func parseTopicWithQuiz() {
        let markdown = """
        ---
        id: quiz-test
        title: Quiz Test
        summary: Testing quiz parsing
        quiz:
          - question: "What is 2+2?"
            options:
              - "3"
              - "4"
              - "5"
            correct: 1
        ---
        Body
        """

        let result = FrontmatterParser.parseTopic(
            markdown: markdown,
            categoryId: "math",
            contentPath: "math/quiz-test.md"
        )

        #expect(result != nil)
        #expect(result!.topic.quiz != nil)
        #expect(result!.topic.quiz?.count == 1)
        let q = result!.topic.quiz![0]
        #expect(q.question == "What is 2+2?")
        #expect(q.options == ["3", "4", "5"])
        #expect(q.correctAnswerIndex == 1)
    }

    @Test func parseTopicMalformedInput() {
        let result = FrontmatterParser.parseTopic(
            markdown: "No frontmatter at all",
            categoryId: "cat",
            contentPath: "cat/bad.md"
        )
        #expect(result == nil)
    }

    // MARK: - YAML Edge Cases

    @Test func parseYAMLComments() {
        let markdown = """
        ---
        # This is a comment
        id: commented
        title: Commented Topic
        summary: Has comments
        ---
        Body
        """

        let result = FrontmatterParser.parse(markdown)
        #expect(result != nil)
        #expect(result?.fields["id"] as? String == "commented")
    }

    @Test func parseYAMLEmptyLines() {
        let markdown = """
        ---
        id: spaced

        title: Spaced Topic

        summary: Has empty lines
        ---
        Body
        """

        let result = FrontmatterParser.parse(markdown)
        #expect(result != nil)
        #expect(result?.fields["id"] as? String == "spaced")
        #expect(result?.fields["title"] as? String == "Spaced Topic")
        #expect(result?.fields["summary"] as? String == "Has empty lines")
    }
}
