//
//  EmojiShortcodeTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 15.03.26.
//

import XCTest
@testable import PIRATEN

final class EmojiShortcodeTests: XCTestCase {

    // MARK: - Plain text shortcodes (e.g. topic titles / subject lines)

    func testPlainShortcodeReplacedWithUnicode() {
        let input = "Hello :wave: world"
        let result = HTMLContentParser.replaceEmojiShortcodes(in: input)
        XCTAssertEqual(result, "Hello 👋 world")
    }

    func testMultipleShortcodesReplaced() {
        let input = ":thumbsup: Great idea :heart:"
        let result = HTMLContentParser.replaceEmojiShortcodes(in: input)
        XCTAssertEqual(result, "👍 Great idea ❤️")
    }

    func testSkinToneSuffixStripped() {
        let input = "Hey :wave:t2:"
        let result = HTMLContentParser.replaceEmojiShortcodes(in: input)
        XCTAssertEqual(result, "Hey 👋")
    }

    func testUnknownShortcodeLeftAsIs() {
        let input = "Check :not_a_real_emoji:"
        let result = HTMLContentParser.replaceEmojiShortcodes(in: input)
        XCTAssertEqual(result, "Check :not_a_real_emoji:")
    }

    // MARK: - HTML emoji <img> tags (e.g. post bodies)

    func testEmojiImgTagWithTitleReplaced() {
        let input = #"<p>Hello <img src="/images/emoji/twitter/wave.png?v=12" title=":wave:" class="emoji" alt=":wave:" loading="lazy" width="20" height="20"> world</p>"#
        let result = HTMLContentParser.replaceEmojiShortcodes(in: input)
        XCTAssertTrue(result.contains("👋"), "Expected wave emoji, got: \(result)")
        XCTAssertFalse(result.contains("<img"), "Expected img tag to be removed")
    }

    func testEmojiImgTagWithAltOnlyReplaced() {
        // Simulate a tag without title attribute, only alt
        let input = #"<p>Hi <img src="/images/emoji/twitter/smile.png" class="emoji" alt=":smile:" width="20" height="20"> there</p>"#
        let result = HTMLContentParser.replaceEmojiShortcodes(in: input)
        XCTAssertTrue(result.contains("😄"), "Expected smile emoji, got: \(result)")
        XCTAssertFalse(result.contains("<img"), "Expected img tag to be removed")
    }

    func testRemainingEmojiImgTagRemoved() {
        // An emoji img tag with no recognisable shortcode should be removed entirely
        let input = #"<p>Test <img src="/images/emoji/custom/pirate.png" class="emoji emoji-custom" width="20" height="20"> end</p>"#
        let result = HTMLContentParser.replaceEmojiShortcodes(in: input)
        XCTAssertFalse(result.contains("<img"), "Expected remaining emoji img tag to be removed")
    }

    func testPlusOneShortcodeReplaced() {
        let input = ":+1: agreed"
        let result = HTMLContentParser.replaceEmojiShortcodes(in: input)
        XCTAssertEqual(result, "👍 agreed")
    }

    func testPlusOneSkinToneStripped() {
        let input = ":+1:t3:"
        let result = HTMLContentParser.replaceEmojiShortcodes(in: input)
        XCTAssertEqual(result, "👍")
    }

    // MARK: - parseToAttributedString

    func testParseToAttributedStringResolvesEmoji() {
        let input = "<p>Hello :wave:</p>"
        let result = HTMLContentParser.parseToAttributedString(input)
        let text = String(result.characters)
        XCTAssertTrue(text.contains("👋"), "Expected wave emoji in attributed string, got: \(text)")
        XCTAssertFalse(text.contains(":wave:"), "Shortcode should not remain in attributed string")
    }
}
