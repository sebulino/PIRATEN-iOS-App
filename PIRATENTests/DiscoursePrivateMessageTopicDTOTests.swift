//
//  DiscoursePrivateMessageTopicDTOTests.swift
//  PIRATENTests
//
//  Regression coverage for the Bug #3 fix: previously the MessageThread
//  DTO only checked the `unseen` field, which becomes false forever once
//  the user opens a thread the first time. New replies in
//  already-opened threads were therefore invisible to the unread-state
//  logic. This file pins the corrected behaviour: a thread is unread
//  if *any* of `unseen`, `unread_posts`, or
//  `highest_post_number > last_read_post_number` says so.
//

import Foundation
import Testing
@testable import PIRATEN

struct DiscoursePrivateMessageTopicDTOTests {

    // MARK: - Read-state contract

    @Test func unseenTrueIsAlwaysUnread() throws {
        let json = makeJSON(unseen: true)
        let thread = try decode(json)
        #expect(thread.isRead == false)
    }

    @Test func unseenFalseWithoutOtherSignalsIsRead() throws {
        // Default state for an opened thread without new replies.
        let json = makeJSON(unseen: false)
        let thread = try decode(json)
        #expect(thread.isRead == true)
    }

    @Test func unseenFalseWithUnreadPostsIsUnread() throws {
        // This is the Bug #3 case: user opened the thread, then a reply
        // arrived. Discourse leaves `unseen=false` but sets unread_posts.
        let json = makeJSON(unseen: false, unreadPosts: 1)
        let thread = try decode(json)
        #expect(thread.isRead == false)
    }

    @Test func unseenFalseWithHigherPostNumberIsUnread() throws {
        // Alternative shape from some Discourse versions: only the post-
        // number deltas come through, not unread_posts.
        let json = makeJSON(unseen: false, highestPostNumber: 5, lastReadPostNumber: 3)
        let thread = try decode(json)
        #expect(thread.isRead == false)
    }

    @Test func equalPostNumbersAreRead() throws {
        let json = makeJSON(unseen: false, highestPostNumber: 5, lastReadPostNumber: 5)
        let thread = try decode(json)
        #expect(thread.isRead == true)
    }

    @Test func missingAllSignalsDefaultsToRead() throws {
        // Conservative default — never falsely badge a thread as unread
        // just because the API response was incomplete.
        let json = makeJSON()
        let thread = try decode(json)
        #expect(thread.isRead == true)
    }

    // MARK: - Helpers

    /// Decodes a private-message-list response containing a single topic.
    /// Returns the corresponding domain MessageThread.
    private func decode(_ topicJSON: String) throws -> MessageThread {
        let envelope = """
        {
          "users": [{ "id": 1, "username": "alice", "name": "Alice" }],
          "topic_list": { "topics": [\(topicJSON)] }
        }
        """
        let data = Data(envelope.utf8)
        let response = try JSONDecoder().decode(DiscoursePrivateMessagesResponse.self, from: data)
        let users = response.users
        guard let dto = response.topicList.topics.first,
              let thread = dto.toDomainModel(users: users) else {
            throw NSError(domain: "test", code: 0)
        }
        return thread
    }

    /// Builds one topic JSON object with the requested signal values.
    /// All optional fields default to nil so each test focuses on the
    /// signals it actually exercises.
    private func makeJSON(
        unseen: Bool? = nil,
        unreadPosts: Int? = nil,
        highestPostNumber: Int? = nil,
        lastReadPostNumber: Int? = nil
    ) -> String {
        var fields: [String] = [
            "\"id\": 42",
            "\"title\": \"Test thread\"",
            "\"posts_count\": 3",
            "\"created_at\": \"2026-05-25T10:00:00.000Z\"",
            "\"last_posted_at\": \"2026-05-25T11:00:00.000Z\"",
            "\"posters\": [{ \"user_id\": 1, \"description\": \"Original Poster\" }]",
        ]
        if let unseen { fields.append("\"unseen\": \(unseen)") }
        if let unreadPosts { fields.append("\"unread_posts\": \(unreadPosts)") }
        if let highestPostNumber { fields.append("\"highest_post_number\": \(highestPostNumber)") }
        if let lastReadPostNumber { fields.append("\"last_read_post_number\": \(lastReadPostNumber)") }
        return "{ \(fields.joined(separator: ", ")) }"
    }
}
