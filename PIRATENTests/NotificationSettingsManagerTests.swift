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

    // UserDefaults key (must match NotificationSettingsManager.Keys)
    private let enabledKey = "notification_enabled"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: enabledKey)
        sut = NotificationSettingsManager()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: enabledKey)
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateNotificationsDisabled() {
        XCTAssertFalse(sut.notificationsEnabled)
    }

    func testInitLoadsPreferenceFromUserDefaults() {
        // Given: preference stored in UserDefaults
        UserDefaults.standard.set(true, forKey: enabledKey)

        // When: creating a new manager
        let manager = NotificationSettingsManager()

        // Then
        XCTAssertTrue(manager.notificationsEnabled)
    }

    // MARK: - Toggle Persistence

    func testEnablingNotificationsPersistsToUserDefaults() {
        sut.notificationsEnabled = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: enabledKey))
    }

    func testDisablingNotificationsPersistsFalse() {
        sut.notificationsEnabled = true
        sut.notificationsEnabled = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: enabledKey))
    }

    // MARK: - Clear All Settings

    func testClearAllSettingsResetsEverything() {
        // Given: notifications enabled
        sut.notificationsEnabled = true

        // When
        sut.clearAllSettings()

        // Then
        XCTAssertFalse(sut.notificationsEnabled)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: enabledKey))
    }
}
