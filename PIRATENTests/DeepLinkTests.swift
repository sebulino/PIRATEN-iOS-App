//
//  DeepLinkTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 08.02.26.
//

import XCTest
@testable import PIRATEN

final class DeepLinkTests: XCTestCase {

    // MARK: - DeepLink.from(userInfo:) Tests

    func testParseMessageThreadDeepLink() {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "deepLink": "message",
            "topicId": 12345
        ]

        // When
        let deepLink = DeepLink.from(userInfo: userInfo)

        // Then
        XCTAssertEqual(deepLink, .messageThread(topicId: 12345))
    }

    func testParseTodoDetailDeepLink() {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "deepLink": "todo",
            "todoId": "abc-123"
        ]

        // When
        let deepLink = DeepLink.from(userInfo: userInfo)

        // Then
        XCTAssertEqual(deepLink, .todoDetail(todoId: "abc-123"))
    }

    func testParseReturnsNilWhenDeepLinkKeyMissing() {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "topicId": 12345
        ]

        // When
        let deepLink = DeepLink.from(userInfo: userInfo)

        // Then
        XCTAssertNil(deepLink)
    }

    func testParseReturnsNilWhenDeepLinkTypeUnknown() {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "deepLink": "unknown",
            "someId": 123
        ]

        // When
        let deepLink = DeepLink.from(userInfo: userInfo)

        // Then
        XCTAssertNil(deepLink)
    }

    func testParseReturnsNilWhenMessageTopicIdMissing() {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "deepLink": "message"
        ]

        // When
        let deepLink = DeepLink.from(userInfo: userInfo)

        // Then
        XCTAssertNil(deepLink)
    }

    func testParseReturnsNilWhenMessageTopicIdWrongType() {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "deepLink": "message",
            "topicId": "not-an-int"
        ]

        // When
        let deepLink = DeepLink.from(userInfo: userInfo)

        // Then
        XCTAssertNil(deepLink)
    }

    func testParseReturnsNilWhenTodoIdMissing() {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "deepLink": "todo"
        ]

        // When
        let deepLink = DeepLink.from(userInfo: userInfo)

        // Then
        XCTAssertNil(deepLink)
    }

    func testParseReturnsNilWhenTodoIdWrongType() {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "deepLink": "todo",
            "todoId": 123
        ]

        // When
        let deepLink = DeepLink.from(userInfo: userInfo)

        // Then
        XCTAssertNil(deepLink)
    }
}
