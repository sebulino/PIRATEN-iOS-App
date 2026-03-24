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

    // UserDefaults keys (must match NotificationSettingsManager.Keys)
    private let messagesKey = "notification_messages_enabled"
    private let forumKey = "notification_forum_enabled"
    private let todosKey = "notification_todos_enabled"
    private let newsKey = "notification_news_enabled"

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: messagesKey)
        defaults.removeObject(forKey: forumKey)
        defaults.removeObject(forKey: todosKey)
        defaults.removeObject(forKey: newsKey)
        sut = NotificationSettingsManager()
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: messagesKey)
        defaults.removeObject(forKey: forumKey)
        defaults.removeObject(forKey: todosKey)
        defaults.removeObject(forKey: newsKey)
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateAllDisabled() {
        XCTAssertFalse(sut.messagesEnabled)
        XCTAssertFalse(sut.forumEnabled)
        XCTAssertFalse(sut.todosEnabled)
        XCTAssertFalse(sut.newsEnabled)
        XCTAssertFalse(sut.anyNotificationsEnabled)
    }

    func testInitLoadsPreferenceFromUserDefaults() {
        UserDefaults.standard.set(true, forKey: messagesKey)
        UserDefaults.standard.set(true, forKey: forumKey)

        let manager = NotificationSettingsManager()

        XCTAssertTrue(manager.messagesEnabled)
        XCTAssertTrue(manager.forumEnabled)
        XCTAssertFalse(manager.todosEnabled)
        XCTAssertFalse(manager.newsEnabled)
    }

    // MARK: - Toggle Persistence

    func testEnablingCategoryPersistsToUserDefaults() {
        sut.messagesEnabled = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: messagesKey))

        sut.forumEnabled = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: forumKey))
    }

    func testDisablingCategoryPersistsFalse() {
        sut.todosEnabled = true
        sut.todosEnabled = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: todosKey))
    }

    // MARK: - Any Notifications Enabled

    func testAnyNotificationsEnabledWhenOneIsOn() {
        sut.newsEnabled = true
        XCTAssertTrue(sut.anyNotificationsEnabled)
    }

    func testAnyNotificationsDisabledWhenAllOff() {
        sut.messagesEnabled = false
        sut.forumEnabled = false
        sut.todosEnabled = false
        sut.newsEnabled = false
        XCTAssertFalse(sut.anyNotificationsEnabled)
    }

    // MARK: - Clear All Settings

    func testClearAllSettingsResetsEverything() {
        sut.messagesEnabled = true
        sut.forumEnabled = true
        sut.todosEnabled = true
        sut.newsEnabled = true

        sut.clearAllSettings()

        XCTAssertFalse(sut.messagesEnabled)
        XCTAssertFalse(sut.forumEnabled)
        XCTAssertFalse(sut.todosEnabled)
        XCTAssertFalse(sut.newsEnabled)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: messagesKey))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: forumKey))
    }
}
