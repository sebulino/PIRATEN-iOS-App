//
//  DiscourseNotificationPollerTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 23.03.26.
//

import XCTest
@testable import PIRATEN

// MARK: - Mock HTTP Client

/// A mock HTTP client that returns predefined responses for testing.
private final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    var responseData: Data?
    var responseStatusCode: Int = 200
    var shouldThrow = false
    var requestCount = 0

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        requestCount += 1
        if shouldThrow {
            throw HTTPError.networkError("test error")
        }
        return HTTPResponse(
            data: responseData ?? Data(),
            statusCode: responseStatusCode,
            headers: [:]
        )
    }
}

@MainActor
final class DiscourseNotificationPollerTests: XCTestCase {

    private var sut: DiscourseNotificationPoller!
    private var mockHTTPClient: MockHTTPClient!
    private var notificationSettingsManager: NotificationSettingsManager!
    private let baseURL = URL(string: "https://discourse.example.com")!

    // UserDefaults key
    private let lastTotalKey = "discourse_notification_last_total"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: lastTotalKey)
        mockHTTPClient = MockHTTPClient()
        notificationSettingsManager = NotificationSettingsManager()
        sut = DiscourseNotificationPoller(
            httpClient: mockHTTPClient,
            baseURL: baseURL,
            notificationSettingsManager: notificationSettingsManager
        )
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: lastTotalKey)
        sut = nil
        mockHTTPClient = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialLastKnownTotalIsZero() {
        XCTAssertEqual(sut.lastKnownTotal, 0)
    }

    func testPollPersistsLastKnownTotalToUserDefaults() async {
        // When: poll returns a count
        mockHTTPClient.responseData = makeResponseData(unreadNotifications: 5)
        _ = await sut.poll()

        // Then: creating a new poller reads the persisted value
        let newPoller = DiscourseNotificationPoller(
            httpClient: mockHTTPClient,
            baseURL: baseURL,
            notificationSettingsManager: notificationSettingsManager
        )
        XCTAssertEqual(newPoller.lastKnownTotal, 5)
    }

    // MARK: - Polling

    func testPollUpdatesLastKnownTotal() async {
        mockHTTPClient.responseData = makeResponseData(unreadNotifications: 3)

        let result = await sut.poll()

        XCTAssertEqual(result, 3)
        XCTAssertEqual(sut.lastKnownTotal, 3)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: lastTotalKey), 3)
    }

    func testPollReturnsNilOnFailure() async {
        mockHTTPClient.shouldThrow = true

        let result = await sut.poll()

        XCTAssertNil(result)
    }

    func testPollMakesHTTPRequest() async {
        mockHTTPClient.responseData = makeResponseData(unreadNotifications: 0)

        _ = await sut.poll()

        XCTAssertEqual(mockHTTPClient.requestCount, 1)
    }

    // MARK: - Reset

    func testResetClearsStoredCounts() async {
        // First poll to set a non-zero value
        mockHTTPClient.responseData = makeResponseData(unreadNotifications: 10)
        _ = await sut.poll()
        XCTAssertEqual(sut.lastKnownTotal, 10)

        // When
        sut.reset()

        // Then
        XCTAssertEqual(sut.lastKnownTotal, 0)
    }

    // MARK: - Helpers

    private func makeResponseData(unreadNotifications: Int) -> Data {
        let json = """
        {"unread_notifications": \(unreadNotifications)}
        """
        return json.data(using: .utf8)!
    }
}
