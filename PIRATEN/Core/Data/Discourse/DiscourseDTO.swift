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

// MARK: - /t/{topic_id}.json Response DTOs

/// Root response from Discourse /t/{topic_id}.json endpoint.
/// Contains topic metadata and the post stream with posts.
///
/// API Reference: GET /t/{topic_id}.json
/// - Returns topic details plus first 20 posts in post_stream.posts
/// - post_stream.stream contains all post IDs for pagination
struct DiscourseTopicDetailResponse: Decodable {
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

    /// Contains posts and the full stream of post IDs
    let postStream: DiscoursePostStreamDTO

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
        case postStream = "post_stream"
    }

    /// Converts this DTO to a Domain Topic model.
    /// - Parameter firstPostAuthor: The author of the first post (topic creator)
    /// - Returns: A Domain Topic
    func toDomainModel(firstPostAuthor: UserSummary) -> Topic? {
        // Parse the ISO 8601 date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

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
            createdBy: firstPostAuthor,
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

/// Container for posts and the full post ID stream.
struct DiscoursePostStreamDTO: Decodable {
    /// Array of posts (first 20 by default)
    let posts: [DiscoursePostDTO]

    /// Array of all post IDs in the topic (for pagination)
    let stream: [Int]?
}

/// A post from the Discourse API.
/// Maps to the Domain Post model via toDomainModel().
struct DiscoursePostDTO: Decodable {
    let id: Int
    let topicId: Int
    let postNumber: Int
    let username: String
    let name: String?
    let avatarTemplate: String?
    let createdAt: String

    /// HTML-rendered post content (Discourse calls it "cooked")
    let cooked: String

    let replyCount: Int
    let reads: Int?

    /// Number of likes (from actions_summary or direct field)
    /// Note: likes may come from actions_summary array in some responses
    let likeCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case topicId = "topic_id"
        case postNumber = "post_number"
        case username
        case name
        case avatarTemplate = "avatar_template"
        case createdAt = "created_at"
        case cooked
        case replyCount = "reply_count"
        case reads
        case likeCount = "like_count"
    }

    /// Converts this DTO to a Domain Post model.
    /// - Returns: A Domain Post, or nil if conversion fails
    func toDomainModel() -> Post? {
        // Parse the ISO 8601 date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var parsedDate = formatter.date(from: createdAt)
        if parsedDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            parsedDate = formatter.date(from: createdAt)
        }

        guard let date = parsedDate else {
            return nil
        }

        // Build author UserSummary
        let author = buildAuthor()

        return Post(
            id: id,
            topicId: topicId,
            postNumber: postNumber,
            author: author,
            createdAt: date,
            content: cooked,
            replyCount: replyCount,
            likeCount: likeCount ?? 0,
            isRead: (reads ?? 0) > 0
        )
    }

    /// Builds a UserSummary from the post's author fields.
    private func buildAuthor() -> UserSummary {
        var avatarUrl: URL? = nil
        if let template = avatarTemplate {
            let resolvedPath = template.replacingOccurrences(of: "{size}", with: "120")
            if resolvedPath.hasPrefix("http") {
                avatarUrl = URL(string: resolvedPath)
            } else {
                avatarUrl = URL(string: "https://diskussion.piratenpartei.de\(resolvedPath)")
            }
        }

        return UserSummary(
            id: 0, // Post response doesn't include user ID directly
            username: username,
            displayName: name,
            avatarUrl: avatarUrl
        )
    }
}

// MARK: - /topics/private-messages/{username}.json Response DTOs

/// Root response from Discourse /topics/private-messages/{username}.json endpoint.
/// Similar structure to /latest.json but contains private message topics.
///
/// API Reference: GET /topics/private-messages/{username}.json
/// - Returns private message threads where the user is a participant
/// - Topics have archetype="private_message" and participants instead of category
struct DiscoursePrivateMessagesResponse: Decodable {
    /// Array of user objects referenced by topics via participants
    let users: [DiscourseUserDTO]

    /// The topic list container with private message topics
    let topicList: DiscoursePrivateMessageTopicListDTO

    enum CodingKeys: String, CodingKey {
        case users
        case topicList = "topic_list"
    }
}

/// Container for the list of private message topics.
struct DiscoursePrivateMessageTopicListDTO: Decodable {
    /// Array of private message topics
    let topics: [DiscoursePrivateMessageTopicDTO]
}

/// A private message topic from the Discourse API.
/// Maps to the Domain MessageThread model via toDomainModel().
struct DiscoursePrivateMessageTopicDTO: Decodable {
    let id: Int
    let title: String
    let postsCount: Int
    let createdAt: String
    let lastPostedAt: String?

    /// Whether the topic has been read
    /// Note: Discourse may use highest_post_number vs last_read_post_number to determine this
    let unseen: Bool?

    /// Posters/participants in this private message thread
    let posters: [DiscoursePosterDTO]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case postsCount = "posts_count"
        case createdAt = "created_at"
        case lastPostedAt = "last_posted_at"
        case unseen
        case posters
    }

    /// Converts this DTO to a Domain MessageThread model.
    /// - Parameter users: The users array from the response for looking up participant details
    /// - Returns: A Domain MessageThread, or nil if conversion fails
    func toDomainModel(users: [DiscourseUserDTO]) -> MessageThread? {
        // Map all posters to participants
        let participants = posters.compactMap { poster in
            users.first(where: { $0.id == poster.userId })?.toDomainModel()
        }

        // We need at least one participant
        guard !participants.isEmpty else {
            return nil
        }

        // Parse the ISO 8601 dates
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Parse created_at
        var parsedCreatedAt = formatter.date(from: createdAt)
        if parsedCreatedAt == nil {
            formatter.formatOptions = [.withInternetDateTime]
            parsedCreatedAt = formatter.date(from: createdAt)
        }

        guard let createdDate = parsedCreatedAt else {
            return nil
        }

        // Parse last_posted_at (use created_at as fallback)
        var lastActivityDate = createdDate
        if let lastPosted = lastPostedAt {
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = formatter.date(from: lastPosted) {
                lastActivityDate = parsed
            } else {
                formatter.formatOptions = [.withInternetDateTime]
                if let parsed = formatter.date(from: lastPosted) {
                    lastActivityDate = parsed
                }
            }
        }

        // Find the last poster (typically has description "Most Recent Poster")
        let lastPoster = posters
            .last(where: { $0.description?.contains("Recent") == true || $0.description?.contains("Poster") == true })
            .flatMap { poster in
                users.first(where: { $0.id == poster.userId })?.toDomainModel()
            } ?? participants.last

        return MessageThread(
            id: id,
            title: title,
            participants: participants,
            createdAt: createdDate,
            lastActivityAt: lastActivityDate,
            postsCount: postsCount,
            isRead: unseen != true,
            lastPoster: lastPoster
        )
    }
}
