//
//  TelegramAPIClientTests.swift
//  PIRATENTests
//

import Foundation
import Testing
@testable import PIRATEN

@Suite("TelegramAPIClient Tests")
struct TelegramAPIClientTests {

    // MARK: - JSON Parsing Tests

    @Test("Parses valid Telegram API response")
    func parseValidResponse() async throws {
        let json = """
        {
            "ok": true,
            "result": [
                {
                    "update_id": 100,
                    "message": {
                        "message_id": 42,
                        "date": 1708700000,
                        "text": "Hello Piraten!",
                        "chat": {"id": -1001234567890},
                        "from": {"first_name": "Bot", "last_name": "News"}
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let mockHTTP = MockHTTPClient(responseData: json, statusCode: 200)
        let client = TelegramAPIClient(httpClient: mockHTTP, botToken: "test-token", chatId: -1001234567890)

        let posts = try await client.fetchMessages()
        #expect(posts.count == 1)
        #expect(posts[0].id == 42)
        #expect(posts[0].text == "Hello Piraten!")
        #expect(posts[0].authorName == "Bot News")
    }

    @Test("Filters messages by chat ID")
    func filtersByChatId() async throws {
        let json = """
        {
            "ok": true,
            "result": [
                {
                    "update_id": 100,
                    "message": {
                        "message_id": 1,
                        "date": 1708700000,
                        "text": "Correct chat",
                        "chat": {"id": -1001234567890},
                        "from": {"first_name": "Bot"}
                    }
                },
                {
                    "update_id": 101,
                    "message": {
                        "message_id": 2,
                        "date": 1708700001,
                        "text": "Wrong chat",
                        "chat": {"id": -9999999999},
                        "from": {"first_name": "Other"}
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let mockHTTP = MockHTTPClient(responseData: json, statusCode: 200)
        let client = TelegramAPIClient(httpClient: mockHTTP, botToken: "test-token", chatId: -1001234567890)

        let posts = try await client.fetchMessages()
        #expect(posts.count == 1)
        #expect(posts[0].text == "Correct chat")
    }

    @Test("Maps author name from first and last name")
    func mapsAuthorName() async throws {
        let json = """
        {
            "ok": true,
            "result": [
                {
                    "update_id": 100,
                    "message": {
                        "message_id": 1,
                        "date": 1708700000,
                        "text": "Test",
                        "chat": {"id": 123},
                        "from": {"first_name": "Max", "last_name": "Mustermann"}
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let mockHTTP = MockHTTPClient(responseData: json, statusCode: 200)
        let client = TelegramAPIClient(httpClient: mockHTTP, botToken: "test-token", chatId: 123)

        let posts = try await client.fetchMessages()
        #expect(posts[0].authorName == "Max Mustermann")
    }

    @Test("Handles messages without from field")
    func handlesNoAuthor() async throws {
        let json = """
        {
            "ok": true,
            "result": [
                {
                    "update_id": 100,
                    "message": {
                        "message_id": 1,
                        "date": 1708700000,
                        "text": "No author",
                        "chat": {"id": 123}
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let mockHTTP = MockHTTPClient(responseData: json, statusCode: 200)
        let client = TelegramAPIClient(httpClient: mockHTTP, botToken: "test-token", chatId: 123)

        let posts = try await client.fetchMessages()
        #expect(posts[0].authorName == nil)
    }

    @Test("Throws on API error status")
    func throwsOnAPIError() async throws {
        let json = """
        {"ok": false, "result": []}
        """.data(using: .utf8)!

        let mockHTTP = MockHTTPClient(responseData: json, statusCode: 200)
        let client = TelegramAPIClient(httpClient: mockHTTP, botToken: "test-token", chatId: 123)

        do {
            _ = try await client.fetchMessages()
            Issue.record("Expected error to be thrown")
        } catch {
            // Expected
        }
    }

    @Test("Throws on HTTP error")
    func throwsOnHTTPError() async throws {
        let mockHTTP = MockHTTPClient(responseData: Data(), statusCode: 500)
        let client = TelegramAPIClient(httpClient: mockHTTP, botToken: "test-token", chatId: 123)

        do {
            _ = try await client.fetchMessages()
            Issue.record("Expected error to be thrown")
        } catch {
            // Expected
        }
    }
}

// MARK: - Mock HTTP Client

private final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    let responseData: Data
    let statusCode: Int

    init(responseData: Data, statusCode: Int) {
        self.responseData = responseData
        self.statusCode = statusCode
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        HTTPResponse(data: responseData, statusCode: statusCode, headers: [:])
    }
}
