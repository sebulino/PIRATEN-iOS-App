//
//  DiscourseDTO.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

// MARK: - /latest.json Response DTOs

/// Root response from Discourse /latest.json endpoint.
/// Contains both the user lookup table and the topic list.
///
/// API Reference: GET /latest.json
/// Response shape based on Discourse API documentation.
struct DiscourseLatestResponse: Decodable {
    /// Array of user objects referenced by topics via posters
    let users: [DiscourseUserDTO]

    /// The topic list container
    let topicList: DiscourseTopicListDTO

    enum CodingKeys: String, CodingKey {
        case users
        case topicList = "topic_list"
    }
}

/// Container for the list of topics.
struct DiscourseTopicListDTO: Decodable {
    /// Array of topics
    let topics: [DiscourseTopicDTO]
}

/// A topic from the Discourse API.
/// Maps to the Domain Topic model via toDomainModel().
struct DiscourseTopicDTO: Decodable {
    let id: Int
    let title: String
    let postsCount: Int
    let views: Int
    let likeCount: Int
    let categoryId: Int
    let visible: Bool
    let closed: Bool
    let archived: Bool
    let createdAt: String

    /// Array of poster references. The first one is typically the OP (original poster).
    let posters: [DiscoursePosterDTO]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case postsCount = "posts_count"
        case views
        case likeCount = "like_count"
        case categoryId = "category_id"
        case visible
        case closed
        case archived
        case createdAt = "created_at"
        case posters
    }

    /// Converts this DTO to a Domain Topic model.
    /// - Parameter users: The users array from the response for looking up poster details
    /// - Returns: A Domain Topic, or nil if conversion fails (e.g., missing OP)
    func toDomainModel(users: [DiscourseUserDTO]) -> Topic? {
        // Find the original poster (first poster in the list)
        guard let firstPoster = posters.first,
              let user = users.first(where: { $0.id == firstPoster.userId }) else {
            return nil
        }

        // Parse the ISO 8601 date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Try with fractional seconds first, then without
        var parsedDate = formatter.date(from: createdAt)
        if parsedDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            parsedDate = formatter.date(from: createdAt)
        }

        guard let date = parsedDate else {
            return nil
        }

        return Topic(
            id: id,
            title: title,
            createdBy: user.toDomainModel(),
            createdAt: date,
            postsCount: postsCount,
            viewCount: views,
            likeCount: likeCount,
            categoryId: categoryId,
            isVisible: visible,
            isClosed: closed,
            isArchived: archived
        )
    }
}

/// A poster reference in a topic.
/// Contains the user_id to look up in the users array.
struct DiscoursePosterDTO: Decodable {
    let userId: Int

    /// Description of the poster role (e.g., "Original Poster", "Frequent Poster")
    let description: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case description
    }
}

/// A user from the Discourse API.
/// Maps to the Domain UserSummary model.
struct DiscourseUserDTO: Decodable {
    let id: Int
    let username: String
    let name: String?

    /// Avatar URL template. Contains "{size}" placeholder.
    /// Example: "/user_avatar/diskussion.piratenpartei.de/username/{size}/12345_2.png"
    let avatarTemplate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case name
        case avatarTemplate = "avatar_template"
    }

    /// Converts this DTO to a Domain UserSummary model.
    func toDomainModel() -> UserSummary {
        // Resolve avatar URL by replacing the size placeholder
        var avatarUrl: URL? = nil
        if let template = avatarTemplate {
            let resolvedPath = template.replacingOccurrences(of: "{size}", with: "120")
            // The avatar_template can be relative or absolute
            if resolvedPath.hasPrefix("http") {
                avatarUrl = URL(string: resolvedPath)
            } else {
                // Relative URL - prepend base URL
                avatarUrl = URL(string: "https://diskussion.piratenpartei.de\(resolvedPath)")
            }
        }

        return UserSummary(
            id: id,
            username: username,
            displayName: name,
            avatarUrl: avatarUrl
        )
    }
}
