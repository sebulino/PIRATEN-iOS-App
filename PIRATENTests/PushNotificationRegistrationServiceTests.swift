//
//  PushNotificationRegistrationServiceTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 13.03.26.
//

import XCTest
@testable import PIRATEN

final class PushNotificationRegistrationServiceTests: XCTestCase {

    // MARK: - FakePushNotificationRegistrationService Tests

    func testFakeServiceRegisterDoesNotThrow() async throws {
        let service = FakePushNotificationRegistrationService()
        let prefs = PushNotificationPreferences(messagesEnabled: true, todosEnabled: false, forumEnabled: true)

        // Should not throw
        try await service.register(token: "abcdef", preferences: prefs)
    }

    func testFakeServiceUnregisterDoesNotThrow() async throws {
        let service = FakePushNotificationRegistrationService()
        try await service.unregister(token: "abcdef")
    }

    // MARK: - PushNotificationPreferences

    func testPreferencesEquality() {
        let a = PushNotificationPreferences(messagesEnabled: true, todosEnabled: false, forumEnabled: true)
        let b = PushNotificationPreferences(messagesEnabled: true, todosEnabled: false, forumEnabled: true)
        let c = PushNotificationPreferences(messagesEnabled: false, todosEnabled: false, forumEnabled: true)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - BackendPushNotificationRegistrationService Tests

    func testRegisterSkipsSilentlyWhenNoAccessToken() async throws {
        // Given: access token provider returns nil
        let service = BackendPushNotificationRegistrationService(
            baseURL: URL(string: "https://example.com")!,
            accessTokenProvider: { nil }
        )
        let prefs = PushNotificationPreferences(messagesEnabled: true, todosEnabled: false, forumEnabled: false)

        // When/Then: should not throw (skips silently)
        try await service.register(token: "abc123", preferences: prefs)
    }

    func testUnregisterSkipsSilentlyWhenNoAccessToken() async throws {
        // Given: access token provider returns nil
        let service = BackendPushNotificationRegistrationService(
            baseURL: URL(string: "https://example.com")!,
            accessTokenProvider: { nil }
        )

        // When/Then: should not throw (skips silently)
        try await service.unregister(token: "abc123")
    }

    // MARK: - PushRegistrationError

    func testPushRegistrationErrorDescriptions() {
        XCTAssertNotNil(PushRegistrationError.registrationFailed.errorDescription)
        XCTAssertNotNil(PushRegistrationError.unregistrationFailed.errorDescription)
    }
}
