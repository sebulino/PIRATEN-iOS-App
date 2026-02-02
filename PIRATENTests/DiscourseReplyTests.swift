//
//  DiscourseReplyTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 02.02.26.
//

import Foundation
import Testing
@testable import PIRATEN

// MARK: - DiscourseAPIClient Reply Tests

@MainActor
struct DiscourseAPIClientReplyTests {

    @Test func replyToMessageThreadSendsCorrectRequest() async throws {
        let baseURL = URL(string: "https://discourse.example.com")!
        let topicId = 1234
        let content = "This is my reply content"

        // Create a stub that captures the request
        let capturedClient = RequestCapturingStubClient(
            response: .success("""
            {
                "id": 5678,
                "topic_id": 1234,
                "post_number": 3,
                "cooked": "<p>This is my reply content</p>",
                "raw": "This is my reply content"
            }
            """.data(using: .utf8)!, statusCode: 200)
        )

        let apiClient = DiscourseAPIClient(httpClient: capturedClient, baseURL: baseURL)
        _ = try await apiClient.replyToMessageThread(topicId: topicId, content: content)

        // Verify the request was made to the correct endpoint
        let lastRequest = capturedClient.lastRequest
        #expect(lastRequest != nil)
        #expect(lastRequest?.url.absoluteString == "https://discourse.example.com/posts.json")
        #expect(lastRequest?.method == .post)
        #expect(lastRequest?.headers["Content-Type"] == "application/json")
        #expect(lastRequest?.headers["Accept"] == "application/json")

        // Verify the request body contains correct data
        if let body = lastRequest?.body {
            let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
            #expect(json["topic_id"] as? Int == topicId)
            #expect(json["raw"] as? String == content)
        } else {
            Issue.record("Expected request body to be present")
        }
    }

    @Test func replyToMessageThreadThrowsUnauthorizedOn401() async throws {
        let baseURL = URL(string: "https://discourse.example.com")!
        let capturedClient = RequestCapturingStubClient(
            response: .success(Data(), statusCode: 401)
        )

        let apiClient = DiscourseAPIClient(httpClient: capturedClient, baseURL: baseURL)

        do {
            _ = try await apiClient.replyToMessageThread(topicId: 1234, content: "test")
            Issue.record("Expected DiscourseError.unauthorized to be thrown")
        } catch let error as DiscourseError {
            #expect(error == .unauthorized)
        }
    }

    @Test func replyToMessageThreadThrowsForbiddenOn403() async throws {
        let baseURL = URL(string: "https://discourse.example.com")!
        let capturedClient = RequestCapturingStubClient(
            response: .success(Data(), statusCode: 403)
        )

        let apiClient = DiscourseAPIClient(httpClient: capturedClient, baseURL: baseURL)

        do {
            _ = try await apiClient.replyToMessageThread(topicId: 1234, content: "test")
            Issue.record("Expected DiscourseError.forbidden to be thrown")
        } catch let error as DiscourseError {
            #expect(error == .forbidden)
        }
    }

    @Test func replyToMessageThreadThrowsRateLimitedOn429() async throws {
        let baseURL = URL(string: "https://discourse.example.com")!
        let capturedClient = RequestCapturingStubClient(
            response: .success(Data(), statusCode: 429)
        )

        let apiClient = DiscourseAPIClient(httpClient: capturedClient, baseURL: baseURL)

        do {
            _ = try await apiClient.replyToMessageThread(topicId: 1234, content: "test")
            Issue.record("Expected DiscourseError.rateLimited to be thrown")
        } catch let error as DiscourseError {
            #expect(error == .rateLimited)
        }
    }

    @Test func replyToMessageThreadParsesErrorMessage() async throws {
        let baseURL = URL(string: "https://discourse.example.com")!
        let errorResponse = """
        {"errors": ["Body is too short"], "error_type": "invalid_parameters"}
        """.data(using: .utf8)!

        let capturedClient = RequestCapturingStubClient(
            response: .success(errorResponse, statusCode: 422)
        )

        let apiClient = DiscourseAPIClient(httpClient: capturedClient, baseURL: baseURL)

        do {
            _ = try await apiClient.replyToMessageThread(topicId: 1234, content: "x")
            Issue.record("Expected error to be thrown")
        } catch let error as DiscourseError {
            // Status 422 maps to unknown with message
            switch error {
            case .unknown(_, let message):
                #expect(message?.contains("Body is too short") == true)
            default:
                Issue.record("Expected unknown error with message, got \(error)")
            }
        }
    }
}

// MARK: - FakeDiscourseRepository Reply Tests

@MainActor
struct FakeDiscourseRepositoryReplyTests {

    @Test func replyToThreadCompletes() async throws {
        let repository = FakeDiscourseRepository()

        // Should not throw
        try await repository.replyToThread(topicId: 1001, content: "Test reply")
    }
}
