//
//  DiscourseTopicDTOTests.swift
//  PIRATENTests
//
//  Covers the mapping of a forum topic from /latest.json into the domain
//  Topic — specifically the `bumped_at` → `lastActivityAt` field, which the
//  Forum list and the Kajüte render as the "last post" time (falling back to
//  createdAt when absent).
//

import Foundation
import Testing
@testable import PIRATEN

@MainActor
struct DiscourseTopicDTOTests {

    @Test func bumpedAtMapsToLastActivityAt() throws {
        let topic = try decode(makeJSON(bumpedAt: "2026-05-25T11:30:00.000Z"))
        let expected = DiscourseTopicDTO.parseISO8601("2026-05-25T11:30:00.000Z")
        #expect(topic.lastActivityAt == expected)
        // Sanity: bump is after creation, so they must differ.
        #expect(topic.lastActivityAt != topic.createdAt)
    }

    @Test func missingBumpedAtYieldsNilLastActivity() throws {
        // Older/partial payloads omit bumped_at — the display then falls back
        // to createdAt.
        let topic = try decode(makeJSON(bumpedAt: nil))
        #expect(topic.lastActivityAt == nil)
    }

    @Test func bumpedAtWithoutFractionalSecondsParses() throws {
        // Discourse sometimes emits whole-second timestamps.
        let topic = try decode(makeJSON(bumpedAt: "2026-05-25T11:30:00Z"))
        #expect(topic.lastActivityAt != nil)
    }

    // MARK: - Helpers

    /// Decodes a /latest.json envelope with a single topic and returns the
    /// mapped domain Topic.
    private func decode(_ topicJSON: String) throws -> Topic {
        let envelope = """
        {
          "users": [{ "id": 1, "username": "alice", "name": "Alice" }],
          "topic_list": { "topics": [\(topicJSON)] }
        }
        """
        let data = Data(envelope.utf8)
        let response = try JSONDecoder().decode(DiscourseLatestResponse.self, from: data)
        guard let dto = response.topicList.topics.first,
              let topic = dto.toDomainModel(users: response.users) else {
            throw NSError(domain: "test", code: 0)
        }
        return topic
    }

    /// Builds one topic JSON object. `bumpedAt` is included only when non-nil
    /// so the missing-field case can be exercised.
    private func makeJSON(bumpedAt: String?) -> String {
        var fields: [String] = [
            "\"id\": 42",
            "\"title\": \"Test topic\"",
            "\"posts_count\": 3",
            "\"views\": 10",
            "\"like_count\": 1",
            "\"category_id\": 5",
            "\"visible\": true",
            "\"closed\": false",
            "\"archived\": false",
            "\"created_at\": \"2026-05-25T10:00:00.000Z\"",
            "\"posters\": [{ \"user_id\": 1, \"description\": \"Original Poster\" }]",
        ]
        if let bumpedAt { fields.append("\"bumped_at\": \"\(bumpedAt)\"") }
        return "{ \(fields.joined(separator: ", ")) }"
    }
}
