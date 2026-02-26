//
//  NewsAPIClientTests.swift
//  PIRATENTests
//

import Foundation
import Testing
@testable import PIRATEN

@Suite("NewsAPIClient Tests")
struct NewsAPIClientTests {

    // MARK: - JSON Parsing Tests

    @Test("Parses valid news API response")
    func parseValidResponse() async throws {
        let json = """
        [
            {
                "chat_id": -1001,
                "message_id": 42,
                "posted_at": "2026-02-20T14:30:00Z",
                "text": "Hello Piraten!"
            }
        ]
        """.data(using: .utf8)!

        let mockHTTP = MockHTTPClient(responseData: json, statusCode: 200)
        let client = NewsAPIClient(httpClient: mockHTTP, baseURL: URL(string: "https://example.com")!)

        let items = try await client.fetchNews()
        #expect(items.count == 1)
        #expect(items[0].messageId == 42)
        #expect(items[0].chatId == -1001)
        #expect(items[0].text == "Hello Piraten!")
    }

    @Test("Parses dates with fractional seconds")
    func parseFractionalSeconds() async throws {
        let json = """
        [
            {
                "chat_id": -1001,
                "message_id": 1,
                "posted_at": "2026-02-20T14:30:00.123Z",
                "text": "Fractional"
            }
        ]
        """.data(using: .utf8)!

        let mockHTTP = MockHTTPClient(responseData: json, statusCode: 200)
        let client = NewsAPIClient(httpClient: mockHTTP, baseURL: URL(string: "https://example.com")!)

        let items = try await client.fetchNews()
        #expect(items.count == 1)
        #expect(items[0].text == "Fractional")
    }

    @Test("Throws on server error")
    func throwsOnServerError() async throws {
        let mockHTTP = MockHTTPClient(responseData: Data(), statusCode: 500)
        let client = NewsAPIClient(httpClient: mockHTTP, baseURL: URL(string: "https://example.com")!)

        do {
            _ = try await client.fetchNews()
            Issue.record("Expected error to be thrown")
        } catch let error as NewsAPIError {
            if case .serverError(let code) = error {
                #expect(code == 500)
            } else {
                Issue.record("Expected serverError, got \(error)")
            }
        }
    }

    @Test("Throws on invalid JSON")
    func throwsOnInvalidJSON() async throws {
        let json = """
        {"not": "an array"}
        """.data(using: .utf8)!

        let mockHTTP = MockHTTPClient(responseData: json, statusCode: 200)
        let client = NewsAPIClient(httpClient: mockHTTP, baseURL: URL(string: "https://example.com")!)

        do {
            _ = try await client.fetchNews()
            Issue.record("Expected error to be thrown")
        } catch is NewsAPIError {
            // Expected decodingError
        }
    }

    @Test("Headline extracts first line")
    func headlineFirstLine() {
        let item = NewsItem(chatId: 1, messageId: 1, postedAt: Date(), text: "First line\nSecond line\nThird")
        #expect(item.headline == "First line")
    }

    @Test("Headline joins Wer: prefix with second line")
    func headlineWerPrefix() {
        let item = NewsItem(chatId: 1, messageId: 1, postedAt: Date(), text: "Wer: AG Test\nMeeting morgen")
        #expect(item.headline == "Wer: AG Test · Meeting morgen")
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
