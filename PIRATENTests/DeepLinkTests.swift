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

    // MARK: - userInfo encoding (round-trip with from(userInfo:))

    func testUserInfoRoundTripForumTopic() {
        let link = DeepLink.forumTopic(topicId: 123)
        XCTAssertEqual(DeepLink.from(userInfo: link.userInfo), link)
    }

    func testUserInfoRoundTripMessageThread() {
        let link = DeepLink.messageThread(topicId: 456)
        XCTAssertEqual(DeepLink.from(userInfo: link.userInfo), link)
    }

    func testUserInfoRoundTripTodoDetail() {
        let link = DeepLink.todoDetail(todoId: "abc-123")
        XCTAssertEqual(DeepLink.from(userInfo: link.userInfo), link)
    }

    func testForumTopicUserInfoKeys() {
        // The scheduler stamps exactly these keys; AppDelegate reads them back.
        let userInfo = DeepLink.forumTopic(topicId: 7).userInfo
        XCTAssertEqual(userInfo["deepLink"] as? String, "forum")
        XCTAssertEqual(userInfo["topicId"] as? Int, 7)
    }

    func testMessageThreadUserInfoKeys() {
        let userInfo = DeepLink.messageThread(topicId: 9).userInfo
        XCTAssertEqual(userInfo["deepLink"] as? String, "message")
        XCTAssertEqual(userInfo["topicId"] as? Int, 9)
    }
}
