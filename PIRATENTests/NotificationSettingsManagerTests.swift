//
//  NotificationSettingsManagerTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 13.03.26.
//

import XCTest
@testable import PIRATEN

@MainActor
final class NotificationSettingsManagerTests: XCTestCase {

    private var sut: NotificationSettingsManager!

    // UserDefaults keys (must match NotificationSettingsManager.Keys).
    private let messagesKey = "notification_messages_enabled"
    private let forumKey = "notification_forum_enabled"
    private let todosKey = "notification_todos_enabled"
    private let newsKey = "notification_news_enabled"
    private let knowledgeKey = "notification_knowledge_enabled"
    private let eventsKey = "notification_events_enabled"

    private var allKeys: [String] {
        [messagesKey, forumKey, todosKey, newsKey, knowledgeKey, eventsKey]
    }

    // Note on opt-out (Q-068): the manager seeds these keys to `true` in the
    // UserDefaults *registration domain* via register(defaults:). Removing the
    // explicit keys here therefore makes a freshly-constructed manager read the
    // registered default (true), not false — which is exactly the opt-out
    // behaviour these tests assert.
    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        allKeys.forEach { defaults.removeObject(forKey: $0) }
        sut = NotificationSettingsManager()
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        allKeys.forEach { defaults.removeObject(forKey: $0) }
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State (opt-out)

    func testInitialStateAllEnabledByDefault() {
        // Fresh install (no explicit keys) → every category on (opt-out).
        XCTAssertTrue(sut.messagesEnabled)
        XCTAssertTrue(sut.forumEnabled)
        XCTAssertTrue(sut.todosEnabled)
        XCTAssertTrue(sut.newsEnabled)
        XCTAssertTrue(sut.knowledgeEnabled)
        XCTAssertTrue(sut.eventsEnabled)
        XCTAssertTrue(sut.anyNotificationsEnabled)
    }

    func testExplicitDisableOverridesOptOutDefault() {
        // Two categories explicitly turned off; the other four untouched.
        UserDefaults.standard.set(false, forKey: todosKey)
        UserDefaults.standard.set(false, forKey: newsKey)

        let manager = NotificationSettingsManager()

        // Explicit `false` wins over the registered opt-out default …
        XCTAssertFalse(manager.todosEnabled)
        XCTAssertFalse(manager.newsEnabled)
        // … while untouched categories keep the opt-out default (on).
        XCTAssertTrue(manager.messagesEnabled)
        XCTAssertTrue(manager.forumEnabled)
        XCTAssertTrue(manager.knowledgeEnabled)
        XCTAssertTrue(manager.eventsEnabled)
    }

    // MARK: - Toggle Persistence

    func testDisablingCategoryPersistsFalse() {
        // The opt-out-relevant direction: a user turning a category off must
        // persist `false`, overriding the registered default on next launch.
        sut.todosEnabled = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: todosKey))

        let reloaded = NotificationSettingsManager()
        XCTAssertFalse(reloaded.todosEnabled)
    }

    func testReEnablingCategoryPersistsTrue() {
        sut.forumEnabled = false
        sut.forumEnabled = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: forumKey))
    }

    // MARK: - Any Notifications Enabled

    func testAnyNotificationsEnabledWhenOnlyOneIsOn() {
        sut.messagesEnabled = false
        sut.forumEnabled = false
        sut.todosEnabled = false
        sut.newsEnabled = false
        sut.knowledgeEnabled = false
        sut.eventsEnabled = true
        XCTAssertTrue(sut.anyNotificationsEnabled)
    }

    func testAnyNotificationsDisabledWhenAllSixOff() {
        sut.messagesEnabled = false
        sut.forumEnabled = false
        sut.todosEnabled = false
        sut.newsEnabled = false
        sut.knowledgeEnabled = false
        sut.eventsEnabled = false
        XCTAssertFalse(sut.anyNotificationsEnabled)
    }

    // MARK: - Clear All Settings (logout)

    func testClearAllSettingsResetsInMemoryFlags() {
        // Logout must silence notifications for the current session: the poller
        // and background coordinator gate on `anyNotificationsEnabled`.
        sut.clearAllSettings()

        XCTAssertFalse(sut.messagesEnabled)
        XCTAssertFalse(sut.forumEnabled)
        XCTAssertFalse(sut.todosEnabled)
        XCTAssertFalse(sut.newsEnabled)
        XCTAssertFalse(sut.knowledgeEnabled)
        XCTAssertFalse(sut.eventsEnabled)
        XCTAssertFalse(sut.anyNotificationsEnabled)
    }

    func testClearAllSettingsRevertsToOptOutForNextSession() {
        // After clearing the explicit keys, a freshly-constructed manager (next
        // launch/login) falls back to the uniform opt-out default — it does NOT
        // inherit the previous user's specific choices (M-2 no-leak property).
        sut.messagesEnabled = false
        sut.forumEnabled = false
        sut.clearAllSettings()

        let nextSession = NotificationSettingsManager()
        XCTAssertTrue(nextSession.messagesEnabled)
        XCTAssertTrue(nextSession.forumEnabled)
        XCTAssertTrue(nextSession.anyNotificationsEnabled)
    }
}
