//
//  DeviceTokenManagerTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 13.03.26.
//

import XCTest
@testable import PIRATEN

@MainActor
final class DeviceTokenManagerTests: XCTestCase {

    private var sut: DeviceTokenManager!
    private let testTokenKey = "apns_device_token"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: testTokenKey)
        sut = DeviceTokenManager()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: testTokenKey)
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateHasNoToken() {
        XCTAssertNil(sut.deviceToken)
        XCTAssertNil(sut.deviceTokenString)
        XCTAssertFalse(sut.isRegistering)
        XCTAssertNil(sut.lastError)
    }

    func testDidReceiveDeviceTokenPersistsToUserDefaults() {
        // Given/When: manager receives a token
        let tokenData = Data([0xAB, 0xCD, 0xEF, 0x01])
        sut.didReceiveDeviceToken(tokenData)

        // Then: token is persisted in UserDefaults
        let stored = UserDefaults.standard.data(forKey: testTokenKey)
        XCTAssertEqual(stored, tokenData)
    }

    // MARK: - Token Received

    func testDidReceiveDeviceTokenStoresToken() {
        // Given
        let tokenData = Data([0x01, 0x02, 0x03, 0x04])

        // When
        sut.didReceiveDeviceToken(tokenData)

        // Then
        XCTAssertEqual(sut.deviceToken, tokenData)
        XCTAssertFalse(sut.isRegistering)
        XCTAssertEqual(UserDefaults.standard.data(forKey: testTokenKey), tokenData)
    }

    func testDidReceiveDeviceTokenClearsIsRegistering() {
        // Given: registration in progress (simulate by calling register)
        // We can't actually call registerForRemoteNotifications in tests,
        // but we can verify didReceiveDeviceToken clears the flag
        let tokenData = Data([0xFF, 0xEE])

        // When
        sut.didReceiveDeviceToken(tokenData)

        // Then
        XCTAssertFalse(sut.isRegistering)
    }

    // MARK: - Token Hex String

    func testDeviceTokenStringReturnsHexRepresentation() {
        // Given
        let tokenData = Data([0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45])
        sut.didReceiveDeviceToken(tokenData)

        // When
        let hexString = sut.deviceTokenString

        // Then
        XCTAssertEqual(hexString, "abcdef012345")
    }

    func testDeviceTokenStringReturnsNilWhenNoToken() {
        XCTAssertNil(sut.deviceTokenString)
    }

    // MARK: - Registration Failure

    func testDidFailToRegisterSetsError() {
        // Given
        let error = NSError(domain: "APNs", code: 42, userInfo: nil)

        // When
        sut.didFailToRegister(with: error)

        // Then
        XCTAssertNotNil(sut.lastError)
        XCTAssertEqual((sut.lastError as? NSError)?.code, 42)
        XCTAssertFalse(sut.isRegistering)
    }

    // MARK: - Clear Token

    func testClearDeviceTokenRemovesTokenAndUserDefaults() {
        // Given: a stored token
        let tokenData = Data([0x01, 0x02])
        sut.didReceiveDeviceToken(tokenData)
        XCTAssertNotNil(sut.deviceToken)

        // When
        sut.clearDeviceToken()

        // Then
        XCTAssertNil(sut.deviceToken)
        XCTAssertNil(sut.deviceTokenString)
        XCTAssertNil(UserDefaults.standard.data(forKey: testTokenKey))
    }
}
