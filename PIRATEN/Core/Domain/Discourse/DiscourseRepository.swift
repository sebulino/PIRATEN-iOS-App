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

    /// Replies to a specific post in a forum topic.
    /// - Parameters:
    ///   - topicId: The ID of the topic containing the post
    ///   - content: The raw text content of the reply
    ///   - replyToPostNumber: Optional post number to reply to (for threading)
    /// - Throws: DiscourseRepositoryError if sending fails
    ///
    /// API Endpoint: POST /posts.json with topic_id, raw, and optional reply_to_post_number
    func replyToForumPost(topicId: Int, content: String, replyToPostNumber: Int?) async throws

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
    /// - Returns: The topic ID of the newly created PM thread (for navigation)
    /// - Throws: DiscourseRepositoryError if creation fails
    ///
    /// API Endpoint: POST /posts.json with archetype=private_message
    func createPrivateMessage(recipient: String, title: String, content: String) async throws -> Int

    /// Fetches a full user profile by username.
    /// - Parameter username: The username to fetch the profile for
    /// - Returns: The user's full profile information
    /// - Throws: DiscourseRepositoryError if fetch fails or user not found
    ///
    /// API Endpoint: GET /u/{username}.json
    func fetchUserProfile(username: String) async throws -> UserProfile

    /// Likes a post on behalf of the current user.
    /// - Parameter id: The ID of the post to like
    /// - Throws: DiscourseRepositoryError if the action fails
    ///
    /// API Endpoint: POST /post_actions.json with post_action_type_id=2
    func likePost(id: Int) async throws

    /// Removes the current user's like from a post.
    /// - Parameter id: The ID of the post to unlike
    /// - Throws: DiscourseRepositoryError if the action fails
    ///
    /// API Endpoint: DELETE /post_actions/{id}.json?post_action_type_id=2
    func unlikePost(id: Int) async throws

    /// Marks a topic (or PM thread) as read by recording read timings with Discourse.
    /// - Parameters:
    ///   - topicId: The ID of the topic to mark as read
    ///   - highestPostNumber: The highest post number (marks all posts up to this as read)
    /// - Throws: DiscourseRepositoryError if the request fails
    ///
    /// API Endpoint: POST /topics/timings
    func markTopicAsRead(topicId: Int, highestPostNumber: Int) async throws

    /// Archives a private message thread.
    /// - Parameter topicId: The ID of the PM topic to archive
    /// - Throws: DiscourseRepositoryError if the request fails
    ///
    /// API Endpoint: PUT /t/{topicId}/archive-message
    func archiveMessageThread(topicId: Int) async throws
}
