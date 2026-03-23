//
//  FeedbackViewModelTests.swift
//  PIRATENTests
//

import XCTest
@testable import PIRATEN

@MainActor
final class FeedbackViewModelTests: XCTestCase {

    // MARK: - Positive Feedback

    func testSendPositiveFeedback() async {
        let repo = MockFeedbackDiscourseRepository()
        let vm = FeedbackViewModel(type: .positive, discourseRepository: repo)
        vm.bodyText = "Die App ist super!"

        await vm.send()

        XCTAssertEqual(vm.state, .sent)
        XCTAssertEqual(repo.lastPMRecipient, "sebulino")
        XCTAssertEqual(repo.lastPMTitle, "App-Feedback: was mir gefällt")
        XCTAssertEqual(repo.lastPMContent, "Die App ist super!")
    }

    // MARK: - Negative Feedback

    func testSendNegativeFeedback() async {
        let repo = MockFeedbackDiscourseRepository()
        let vm = FeedbackViewModel(type: .negative, discourseRepository: repo)
        vm.bodyText = "Die Navigation ist verwirrend."

        await vm.send()

        XCTAssertEqual(vm.state, .sent)
        XCTAssertEqual(repo.lastPMRecipient, "sebulino")
        XCTAssertEqual(repo.lastPMTitle, "App-Feedback: was ich nicht mag")
        XCTAssertEqual(repo.lastPMContent, "Die Navigation ist verwirrend.")
    }

    // MARK: - Empty Body

    func testEmptyBodyDoesNotSend() async {
        let repo = MockFeedbackDiscourseRepository()
        let vm = FeedbackViewModel(type: .positive, discourseRepository: repo)
        vm.bodyText = "   "

        await vm.send()

        XCTAssertEqual(vm.state, .idle)
        XCTAssertNil(repo.lastPMRecipient)
    }

    // MARK: - Failure

    func testFailureShowsErrorState() async {
        let repo = MockFeedbackDiscourseRepository()
        repo.shouldFail = true
        let vm = FeedbackViewModel(type: .positive, discourseRepository: repo)
        vm.bodyText = "Feedback"

        await vm.send()

        if case .failed(let message) = vm.state {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected .failed state, got \(vm.state)")
        }
    }
}

// MARK: - Mock Repository

/// Minimal mock conforming to DiscourseRepository, only capturing createPrivateMessage calls.
@MainActor
private final class MockFeedbackDiscourseRepository: DiscourseRepository {
    var lastPMRecipient: String?
    var lastPMTitle: String?
    var lastPMContent: String?
    var shouldFail = false

    func createPrivateMessage(recipient: String, title: String, content: String) async throws -> Int {
        if shouldFail {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        }
        lastPMRecipient = recipient
        lastPMTitle = title
        lastPMContent = content
        return 999
    }

    // MARK: - Unused stubs

    func fetchTopics() async throws -> [Topic] { [] }
    func fetchPosts(forTopicId topicId: Int) async throws -> [Post] { [] }
    func fetchTopic(byId id: Int) async throws -> Topic {
        throw DiscourseRepositoryError.loadFailed(message: "stub")
    }
    func fetchMessageThreads(for username: String) async throws -> [MessageThread] { [] }
    func replyToThread(topicId: Int, content: String) async throws {}
    func replyToForumPost(topicId: Int, content: String, replyToPostNumber: Int?) async throws {}
    func searchUsers(query: String) async throws -> [UserSearchResult] { [] }
    func fetchUserProfile(username: String) async throws -> UserProfile {
        throw DiscourseRepositoryError.loadFailed(message: "stub")
    }
    func likePost(id: Int) async throws {}
    func unlikePost(id: Int) async throws {}
    func markTopicAsRead(topicId: Int, highestPostNumber: Int) async throws {}
    func archiveMessageThread(topicId: Int) async throws {}
}
