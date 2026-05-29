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

    // MARK: - Notification Category Routing (tap → tab/sheet)

    func testRouteForumCategorySelectsForumTab() {
        sut.routeNotificationCategory("forum")
        XCTAssertEqual(sut.selectedTab, 1)
        XCTAssertFalse(sut.pendingMessagesSheet)
        XCTAssertFalse(sut.pendingNewsSheet)
    }

    func testRouteKnowledgeCategorySelectsWissenTab() {
        sut.routeNotificationCategory("knowledge")
        XCTAssertEqual(sut.selectedTab, 3)
    }

    func testRouteEventsCategorySelectsTermineTab() {
        sut.routeNotificationCategory("events")
        XCTAssertEqual(sut.selectedTab, 4)
    }

    func testRouteTodosCategorySelectsTodosTab() {
        sut.routeNotificationCategory("todos")
        XCTAssertEqual(sut.selectedTab, 5)
    }

    func testRouteMessagesCategoryRaisesMessagesSheet() {
        // Nachrichten is a sheet, not a tab — the flag flips, the tab stays put.
        sut.routeNotificationCategory("messages")
        XCTAssertTrue(sut.pendingMessagesSheet)
        XCTAssertFalse(sut.pendingNewsSheet)
        XCTAssertEqual(sut.selectedTab, 0)
    }

    func testRouteNewsCategoryRaisesNewsSheet() {
        // News is likewise a sheet (there is no tab 2).
        sut.routeNotificationCategory("news")
        XCTAssertTrue(sut.pendingNewsSheet)
        XCTAssertFalse(sut.pendingMessagesSheet)
        XCTAssertEqual(sut.selectedTab, 0)
    }

    func testRouteUnknownCategoryDoesNothing() {
        // An unrecognised category must be a no-op (a tap then just foregrounds
        // the app), never a crash or a wrong-destination jump.
        sut.routeNotificationCategory("totally-unknown")
        XCTAssertEqual(sut.selectedTab, 0)
        XCTAssertFalse(sut.pendingMessagesSheet)
        XCTAssertFalse(sut.pendingNewsSheet)
    }

    /// Drift guard: the router switches on raw strings, while the scheduler
    /// stamps `NotificationCategory.rawValue`. If anyone renames a case (or
    /// adds a seventh category) without teaching the router about it, this
    /// fails — every real category must land on *some* destination.
    ///
    /// NB: reuse the single `sut` instance and reset its state between
    /// categories rather than allocating a fresh `DeepLinkRouter()` per
    /// iteration. Allocating many `ObservableObject`s in a tight loop tripped
    /// a heap-corruption crash ("pointer being freed was not allocated" →
    /// SIGABRT) in the CI toolchain's simulator runtime (Xcode 26.3) — the
    /// app code is fine and it never reproduced locally (Xcode 26.5). The
    /// single-instance pattern the other routing tests use is unaffected.
    func testEveryNotificationCategoryRoutesSomewhere() {
        for category in NotificationCategory.allCases {
            sut.selectedTab = 0
            sut.pendingMessagesSheet = false
            sut.pendingNewsSheet = false

            sut.routeNotificationCategory(category.rawValue)

            let landedOnTab = sut.selectedTab != 0
            let landedOnSheet = sut.pendingMessagesSheet || sut.pendingNewsSheet
            XCTAssertTrue(
                landedOnTab || landedOnSheet,
                "Category '\(category.rawValue)' did not route to any tab or sheet"
            )
        }
    }
}
