//
//  DiscourseRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Error types for Discourse repository operations.
/// Used at the domain layer to communicate failures to the presentation layer.
enum DiscourseRepositoryError: Error, Equatable {
    /// User is not authenticated - should prompt login
    case notAuthenticated

    /// Authentication is invalid (401/403) - session expired
    case authenticationFailed(message: String)

    /// Network or server error that may be retryable
    case loadFailed(message: String)
}

/// Protocol defining the Discourse forum repository interface.
/// This abstraction allows swapping implementations (fake/real) without UI changes.
///
/// All methods are async and throw errors for proper error handling.
/// Implementations should throw DiscourseRepositoryError for domain-level failures.
@MainActor
protocol DiscourseRepository {
    /// Fetches the list of recent topics.
    /// - Returns: Array of topics
    /// - Throws: DiscourseRepositoryError if fetch fails
    func fetchTopics() async throws -> [Topic]

    /// Fetches posts for a specific topic.
    /// - Parameter topicId: The ID of the topic to fetch posts for
    /// - Returns: Array of posts in the topic
    /// - Throws: DiscourseRepositoryError if fetch fails
    func fetchPosts(forTopicId topicId: Int) async throws -> [Post]

    /// Fetches a single topic by ID.
    /// - Parameter id: The topic ID
    /// - Returns: The topic if found
    /// - Throws: DiscourseRepositoryError if fetch fails or topic not found
    func fetchTopic(byId id: Int) async throws -> Topic

    /// Fetches private message threads for the specified user.
    /// - Parameter username: The username to fetch private messages for
    /// - Returns: Array of message threads (PM inbox)
    /// - Throws: DiscourseRepositoryError if fetch fails
    ///
    /// API Endpoint: GET /topics/private-messages/{username}.json
    func fetchMessageThreads(for username: String) async throws -> [MessageThread]

    /// Replies to an existing message thread (PM).
    /// - Parameters:
    ///   - topicId: The ID of the PM thread to reply to
    ///   - content: The raw text content of the reply
    /// - Throws: DiscourseRepositoryError if sending fails
    ///
    /// API Endpoint: POST /posts.json with topic_id and raw parameters
    func replyToThread(topicId: Int, content: String) async throws

    /// Searches for users by username or name.
    /// - Parameter query: The search term (minimum 2 characters recommended)
    /// - Returns: Array of matching users
    /// - Throws: DiscourseRepositoryError if search fails
    ///
    /// API Endpoint: GET /u/search/users.json?term={query}
    /// Used for finding recipients when composing new private messages.
    func searchUsers(query: String) async throws -> [UserSearchResult]

    /// Creates a new private message thread.
    /// - Parameters:
    ///   - recipient: Username of the recipient
    ///   - title: Subject/title of the message
    ///   - content: Body content of the message
    /// - Throws: DiscourseRepositoryError if creation fails
    ///
    /// API Endpoint: POST /posts.json with archetype=private_message
    func createPrivateMessage(recipient: String, title: String, content: String) async throws
}
