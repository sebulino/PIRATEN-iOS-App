//
//  DeepLinkRouterTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 13.03.26.
//

import XCTest
@testable import PIRATEN

@MainActor
final class DeepLinkRouterTests: XCTestCase {

    private var sut: DeepLinkRouter!

    override func setUp() {
        super.setUp()
        sut = DeepLinkRouter()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateHasNoPendingDeepLink() {
        XCTAssertNil(sut.pendingDeepLink)
        XCTAssertEqual(sut.selectedTab, 0)
    }

    // MARK: - Handle Deep Links

    func testHandleMessageThreadSetsPendingDeepLink() {
        // When
        sut.handle(.messageThread(topicId: 42))

        // Then
        XCTAssertEqual(sut.pendingDeepLink, .messageThread(topicId: 42))
    }

    func testHandleMessageThreadDoesNotChangeTab() {
        // Messages are shown as a sheet, not a tab switch
        sut.selectedTab = 3

        // When
        sut.handle(.messageThread(topicId: 42))

        // Then: tab stays the same (messages open via sheet)
        XCTAssertEqual(sut.selectedTab, 3)
    }

    func testHandleTodoDetailSwitchesToTodosTab() {
        // When
        sut.handle(.todoDetail(todoId: "abc-123"))

        // Then
        XCTAssertEqual(sut.pendingDeepLink, .todoDetail(todoId: "abc-123"))
        XCTAssertEqual(sut.selectedTab, 5)
    }

    func testHandleForumTopicSwitchesToForumTab() {
        // When
        sut.handle(.forumTopic(topicId: 99))

        // Then
        XCTAssertEqual(sut.pendingDeepLink, .forumTopic(topicId: 99))
        XCTAssertEqual(sut.selectedTab, 1)
    }

    // MARK: - Clear

    func testClearPendingDeepLinkClearsState() {
        // Given
        sut.handle(.forumTopic(topicId: 1))
        XCTAssertNotNil(sut.pendingDeepLink)

        // When
        sut.clearPendingDeepLink()

        // Then
        XCTAssertNil(sut.pendingDeepLink)
        // Tab should remain where it was set
        XCTAssertEqual(sut.selectedTab, 1)
    }
}
