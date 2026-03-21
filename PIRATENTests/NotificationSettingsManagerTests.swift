//
//  NotificationSettingsManagerTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 13.03.26.
//

import XCTest
@testable import PIRATEN

// MARK: - Spy Registration Service

/// Records all register/unregister calls for test assertions.
final class SpyPushNotificationRegistrationService: PushNotificationRegistrationService {
    var registerCalls: [(token: String, preferences: PushNotificationPreferences)] = []
    var unregisterCalls: [String] = []
    var shouldThrow = false

    func register(token: String, preferences: PushNotificationPreferences) async throws {
        if shouldThrow { throw PushRegistrationError.registrationFailed }
        registerCalls.append((token: token, preferences: preferences))
    }

    func unregister(token: String) async throws {
        if shouldThrow { throw PushRegistrationError.unregistrationFailed }
        unregisterCalls.append(token)
    }
}

@MainActor
final class NotificationSettingsManagerTests: XCTestCase {

    private var sut: NotificationSettingsManager!
    private var deviceTokenManager: DeviceTokenManager!
    private var spyService: SpyPushNotificationRegistrationService!

    // UserDefaults keys (must match NotificationSettingsManager.Keys)
    private let messagesKey = "notification_messages_enabled"
    private let todosKey = "notification_todos_enabled"
    private let forumKey = "notification_forum_enabled"

    override func setUp() {
        super.setUp()
        // Clear notification preferences
        UserDefaults.standard.removeObject(forKey: messagesKey)
        UserDefaults.standard.removeObject(forKey: todosKey)
        UserDefaults.standard.removeObject(forKey: forumKey)
        UserDefaults.standard.removeObject(forKey: "apns_device_token")

        deviceTokenManager = DeviceTokenManager()
        spyService = SpyPushNotificationRegistrationService()
        sut = NotificationSettingsManager(
            deviceTokenManager: deviceTokenManager,
            registrationService: spyService
        )
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: messagesKey)
        UserDefaults.standard.removeObject(forKey: todosKey)
        UserDefaults.standard.removeObject(forKey: forumKey)
        UserDefaults.standard.removeObject(forKey: "apns_device_token")
        sut = nil
        deviceTokenManager = nil
        spyService = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateAllNotificationsDisabled() {
        XCTAssertFalse(sut.messagesEnabled)
        XCTAssertFalse(sut.todosEnabled)
        XCTAssertFalse(sut.forumEnabled)
        XCTAssertFalse(sut.hasAnyNotificationsEnabled)
    }

    func testInitLoadsPreferencesFromUserDefaults() {
        // Given: preferences stored in UserDefaults
        UserDefaults.standard.set(true, forKey: messagesKey)
        UserDefaults.standard.set(true, forKey: forumKey)

        // When: creating a new manager
        let manager = NotificationSettingsManager(
            deviceTokenManager: deviceTokenManager,
            registrationService: spyService
        )

        // Then
        XCTAssertTrue(manager.messagesEnabled)
        XCTAssertFalse(manager.todosEnabled)
        XCTAssertTrue(manager.forumEnabled)
    }

    // MARK: - Toggle Persistence

    func testEnablingMessagesPersistsToUserDefaults() {
        // When
        sut.messagesEnabled = true

        // Then
        XCTAssertTrue(UserDefaults.standard.bool(forKey: messagesKey))
    }

    func testEnablingTodosPersistsToUserDefaults() {
        sut.todosEnabled = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: todosKey))
    }

    func testEnablingForumPersistsToUserDefaults() {
        sut.forumEnabled = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: forumKey))
    }

    func testDisablingPersistsFalse() {
        sut.messagesEnabled = true
        sut.messagesEnabled = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: messagesKey))
    }

    // MARK: - hasAnyNotificationsEnabled

    func testHasAnyNotificationsEnabledWhenMessagesOn() {
        sut.messagesEnabled = true
        XCTAssertTrue(sut.hasAnyNotificationsEnabled)
    }

    func testHasAnyNotificationsEnabledWhenTodosOn() {
        sut.todosEnabled = true
        XCTAssertTrue(sut.hasAnyNotificationsEnabled)
    }

    func testHasAnyNotificationsEnabledWhenForumOn() {
        sut.forumEnabled = true
        XCTAssertTrue(sut.hasAnyNotificationsEnabled)
    }

    func testHasAnyNotificationsDisabledWhenAllOff() {
        XCTAssertFalse(sut.hasAnyNotificationsEnabled)
    }

    // MARK: - Sync Registration on Toggle Change

    func testEnablingPreferenceSyncsToBackendWhenTokenExists() async {
        // Given: a device token is available
        deviceTokenManager.didReceiveDeviceToken(Data([0xAA, 0xBB]))

        // When
        sut.messagesEnabled = true

        // Allow async Task to run
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Then: register was called with correct preferences
        XCTAssertEqual(spyService.registerCalls.count, 1)
        XCTAssertEqual(spyService.registerCalls.first?.token, "aabb")
        XCTAssertEqual(spyService.registerCalls.first?.preferences.messagesEnabled, true)
        XCTAssertEqual(spyService.registerCalls.first?.preferences.todosEnabled, false)
        XCTAssertEqual(spyService.registerCalls.first?.preferences.forumEnabled, false)
    }

    func testDisablingAllPreferencesUnregistersFromBackend() async {
        // Given: messages was enabled and token exists
        deviceTokenManager.didReceiveDeviceToken(Data([0xCC, 0xDD]))
        sut.messagesEnabled = true

        // Allow first sync
        try? await Task.sleep(nanoseconds: 300_000_000)
        spyService.registerCalls.removeAll()

        // When: disable all
        sut.messagesEnabled = false

        // Allow async Task to run
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Then: unregister was called
        XCTAssertEqual(spyService.unregisterCalls.count, 1)
        XCTAssertEqual(spyService.unregisterCalls.first, "ccdd")
    }

    func testNoSyncWhenNoDeviceToken() async {
        // Given: explicitly ensure no device token
        deviceTokenManager.clearDeviceToken()
        XCTAssertNil(deviceTokenManager.deviceTokenString)

        // Recreate manager with clean state
        let cleanSpyService = SpyPushNotificationRegistrationService()
        let cleanManager = NotificationSettingsManager(
            deviceTokenManager: deviceTokenManager,
            registrationService: cleanSpyService
        )

        // When
        cleanManager.messagesEnabled = true

        try? await Task.sleep(nanoseconds: 300_000_000)

        // Then: no calls made (no token to register)
        XCTAssertEqual(cleanSpyService.registerCalls.count, 0)
        XCTAssertEqual(cleanSpyService.unregisterCalls.count, 0)
    }

    func testSyncFailureDoesNotAffectLocalState() async {
        // Given: service will fail
        deviceTokenManager.didReceiveDeviceToken(Data([0x11, 0x22]))
        spyService.shouldThrow = true

        // When
        sut.messagesEnabled = true

        try? await Task.sleep(nanoseconds: 300_000_000)

        // Then: local state is still enabled despite sync failure
        XCTAssertTrue(sut.messagesEnabled)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: messagesKey))
    }

    // MARK: - Clear All Settings

    func testClearAllSettingsResetsEverything() async {
        // Given: preferences enabled and token exists
        deviceTokenManager.didReceiveDeviceToken(Data([0xEE, 0xFF]))
        sut.messagesEnabled = true
        sut.todosEnabled = true
        sut.forumEnabled = true

        try? await Task.sleep(nanoseconds: 300_000_000)
        spyService.registerCalls.removeAll()
        spyService.unregisterCalls.removeAll()

        // When
        sut.clearAllSettings()

        try? await Task.sleep(nanoseconds: 300_000_000)

        // Then: all preferences disabled
        XCTAssertFalse(sut.messagesEnabled)
        XCTAssertFalse(sut.todosEnabled)
        XCTAssertFalse(sut.forumEnabled)

        // UserDefaults cleared
        XCTAssertFalse(UserDefaults.standard.bool(forKey: messagesKey))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: todosKey))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: forumKey))

        // Device token cleared
        XCTAssertNil(deviceTokenManager.deviceToken)

        // Backend unregister was called
        XCTAssertTrue(spyService.unregisterCalls.contains("eeff"))
    }

    // MARK: - Token Change Triggers Sync

    func testChangingMultiplePreferencesSyncsLatestState() async {
        // Given: a device token is available
        deviceTokenManager.didReceiveDeviceToken(Data([0x12, 0x34]))
        try? await Task.sleep(nanoseconds: 300_000_000)
        spyService.registerCalls.removeAll()

        // When: enable multiple preferences
        sut.messagesEnabled = true
        sut.forumEnabled = true
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Then: at least one register call includes both preferences enabled
        let latestCall = spyService.registerCalls.last
        XCTAssertNotNil(latestCall, "Expected at least one register call")
        XCTAssertEqual(latestCall?.token, "1234")
        XCTAssertTrue(latestCall?.preferences.messagesEnabled ?? false)
        XCTAssertTrue(latestCall?.preferences.forumEnabled ?? false)
    }
}
