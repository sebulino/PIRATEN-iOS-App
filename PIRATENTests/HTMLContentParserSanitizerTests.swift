//
//  HTMLContentParserSanitizerTests.swift
//  PIRATENTests
//
//  Coverage for security audit finding H-4: the WebKit-backed
//  NSAttributedString HTML parser fetches remote resources during
//  parsing. HTMLContentParser.sanitizeForOfflineParsing(_:) must
//  strip every construct that can trigger such a fetch, so the
//  parser becomes deterministic and network-free.
//

import Foundation
import Testing
@testable import PIRATEN

struct HTMLContentParserSanitizerTests {

    // MARK: - Tracking pixel removal

    @Test func stripsBareImgTag() {
        let html = "<p>Hi</p><img src=\"https://evil.example.com/pixel.gif\">"
        let result = HTMLContentParser.sanitizeForOfflineParsing(html)
        #expect(!result.contains("img"))
        #expect(!result.contains("evil.example.com"))
    }

    @Test func stripsSelfClosingImg() {
        let html = "<p>Hi</p><img src=\"https://evil.example.com/pixel.gif\" />"
        let result = HTMLContentParser.sanitizeForOfflineParsing(html)
        #expect(!result.contains("<img"))
    }

    @Test func stripsImgWithAttributes() {
        let html = #"<img class="emoji" width="20" height="20" src="https://evil.example.com/pixel.gif" alt="x">"#
        let result = HTMLContentParser.sanitizeForOfflineParsing(html)
        #expect(!result.contains("evil.example.com"))
    }

    @Test func caseInsensitiveImgRemoval() {
        // Discourse occasionally emits IMG (legacy plugins) or mixed case.
        let html = "<IMG SRC=\"https://evil.example.com/x.gif\">"
        let result = HTMLContentParser.sanitizeForOfflineParsing(html)
        #expect(!result.localizedCaseInsensitiveContains("img"))
        #expect(!result.contains("evil.example.com"))
    }

    // MARK: - Other resource-loading tags

    @Test func stripsLinkRelStylesheet() {
        let html = #"<link rel="stylesheet" href="https://evil.example.com/x.css">"#
        let result = HTMLContentParser.sanitizeForOfflineParsing(html)
        #expect(!result.contains("<link"))
        #expect(!result.contains("evil.example.com"))
    }

    @Test func stripsIframeWithContent() {
        let html = "<p>Hello</p><iframe src=\"https://evil.example.com/x\">fallback</iframe><p>Bye</p>"
        let result = HTMLContentParser.sanitizeForOfflineParsing(html)
        #expect(!result.contains("iframe"))
        #expect(!result.contains("fallback"))
        // Surrounding paragraphs preserved
        #expect(result.contains("Hello"))
        #expect(result.contains("Bye"))
    }

    @Test func stripsScriptElement() {
        let html = "<p>Hi</p><script>fetch('https://evil.example.com')</script>"
        let result = HTMLContentParser.sanitizeForOfflineParsing(html)
        #expect(!result.contains("script"))
        #expect(!result.contains("evil.example.com"))
    }

    @Test func stripsStyleElement() {
        let html = "<style>@import url('https://evil.example.com/x.css');</style><p>Hi</p>"
        let result = HTMLContentParser.sanitizeForOfflineParsing(html)
        #expect(!result.contains("style"))
        #expect(!result.contains("evil.example.com"))
    }

    @Test func stripsVideoAndSource() {
        let html = "<video src=\"https://evil.example.com/x.mp4\"><source src=\"https://evil.example.com/y.mp4\"></video>"
        let result = HTMLContentParser.sanitizeForOfflineParsing(html)
        #expect(!result.contains("video"))
        #expect(!result.contains("source"))
        #expect(!result.contains("evil.example.com"))
    }

    // MARK: - Inline-style URL exfiltration

    @Test func stripsInlineStyleAttribute() {
        // `background-image: url(...)` in inline style is a common bypass.
        let html = #"<div style="background-image: url('https://evil.example.com/x.gif')">Hi</div>"#
        let result = HTMLContentParser.sanitizeForOfflineParsing(html)
        #expect(!result.contains("evil.example.com"))
        // The <div> wrapper survives, just without its style attribute
        #expect(result.contains("Hi"))
    }

    @Test func stripsBackgroundAttribute() {
        let html = #"<table background="https://evil.example.com/x.gif"><tr><td>Hi</td></tr></table>"#
        let result = HTMLContentParser.sanitizeForOfflineParsing(html)
        #expect(!result.contains("evil.example.com"))
    }

    // MARK: - Preservation of safe content

    @Test func preservesAnchorTags() {
        // Tappable links must survive — `<a href>` doesn't fetch on parse.
        let html = #"<p>Visit <a href="https://piratenpartei.de">our site</a></p>"#
        let result = HTMLContentParser.sanitizeForOfflineParsing(html)
        #expect(result.contains("<a"))
        #expect(result.contains("href"))
        #expect(result.contains("piratenpartei.de"))
    }

    @Test func preservesTextFormatting() {
        let html = "<p><strong>Bold</strong> and <em>italic</em> text</p>"
        let result = HTMLContentParser.sanitizeForOfflineParsing(html)
        #expect(result.contains("<strong>"))
        #expect(result.contains("<em>"))
        #expect(result.contains("Bold"))
        #expect(result.contains("italic"))
    }

    @Test func preservesPlainTextWithoutHTML() {
        let html = "Just plain text."
        let result = HTMLContentParser.sanitizeForOfflineParsing(html)
        #expect(result == "Just plain text.")
    }
}
