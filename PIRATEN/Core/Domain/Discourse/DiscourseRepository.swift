//
//  DiscourseRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Protocol defining the Discourse forum repository interface.
/// This abstraction allows swapping implementations (fake/real) without UI changes.
///
/// All methods are async to support both in-memory fakes and future network implementations.
/// No HTTP or WebSocket calls are made by implementations until real integration.
@MainActor
protocol DiscourseRepository {
    /// Fetches the list of recent topics.
    /// - Returns: Array of topics, or empty array if fetch fails
    func fetchTopics() async -> [Topic]

    /// Fetches posts for a specific topic.
    /// - Parameter topicId: The ID of the topic to fetch posts for
    /// - Returns: Array of posts in the topic, or empty array if fetch fails
    func fetchPosts(forTopicId topicId: Int) async -> [Post]

    /// Fetches a single topic by ID.
    /// - Parameter id: The topic ID
    /// - Returns: The topic if found, nil otherwise
    func fetchTopic(byId id: Int) async -> Topic?
}
