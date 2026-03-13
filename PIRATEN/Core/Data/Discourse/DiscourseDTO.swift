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

    /// Whether the topic is unseen by the current user
    let unseen: Bool?

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
        case unseen
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
            isArchived: archived,
            isRead: unseen != true
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
    let views: Int?
    let likeCount: Int?
    let categoryId: Int?  // Optional: PMs don't have categories
    let visible: Bool?
    let closed: Bool?
    let archived: Bool?
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
            viewCount: views ?? 0,
            likeCount: likeCount ?? 0,
            categoryId: categoryId ?? 0,  // PMs don't have categories
            isVisible: visible ?? true,
            isClosed: closed ?? false,
            isArchived: archived ?? false,
            isRead: true
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

/// Action summary entry from Discourse API (e.g. likes).
/// Appears in the `actions_summary` array of a post response.
/// - `id == 2` corresponds to the "like" action type.
struct ActionSummaryDTO: Decodable {
    let id: Int
    /// Like count — absent when zero in some Discourse responses
    let count: Int?
    /// True if the current authenticated user has performed this action
    let acted: Bool?
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

    /// Action summaries array; entry with id==2 is the like action
    let actionsSummary: [ActionSummaryDTO]?

    /// The post number this post is replying to (nil if top-level post)
    let replyToPostNumber: Int?

    /// Whether the post was deleted by the author
    let userDeleted: Bool?

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
        case actionsSummary = "actions_summary"
        case replyToPostNumber = "reply_to_post_number"
        case userDeleted = "user_deleted"
    }

    /// Converts this DTO to a Domain Post model.
    /// - Returns: A Domain Post, or nil if conversion fails (or if deleted by author)
    func toDomainModel() -> Post? {
        // Skip posts deleted by the author
        if userDeleted == true { return nil }

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

        // Extract like info from actions_summary (id==2 is the like action)
        let likeAction = actionsSummary?.first(where: { $0.id == 2 })
        let resolvedLikeCount = likeAction?.count ?? likeCount ?? 0
        let likedByCurrentUser = likeAction?.acted ?? false

        return Post(
            id: id,
            topicId: topicId,
            postNumber: postNumber,
            author: author,
            replyToPostNumber: replyToPostNumber,
            createdAt: date,
            content: cooked,
            replyCount: replyCount,
            likeCount: resolvedLikeCount,
            likedByCurrentUser: likedByCurrentUser,
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

// MARK: - /u/search/users.json Response DTOs

/// Root response from Discourse /u/search/users.json endpoint.
/// Returns users matching the search term.
///
/// API Reference: GET /u/search/users.json?term=<query>
/// - Returns users that match the search term by username or name
struct DiscourseUserSearchResponse: Decodable {
    /// Array of users matching the search term
    let users: [DiscourseUserSearchResultDTO]

    /// Groups that can be messaged (optional, may not be present)
    let groups: [DiscourseGroupDTO]?
}

/// A user result from the search API.
/// Contains basic user info for display in recipient picker.
struct DiscourseUserSearchResultDTO: Decodable {
    let username: String
    let name: String?
    let avatarTemplate: String?

    enum CodingKeys: String, CodingKey {
        case username
        case name
        case avatarTemplate = "avatar_template"
    }

    /// Converts this DTO to a Domain UserSearchResult model.
    func toDomainModel() -> UserSearchResult {
        // Resolve avatar URL by replacing the size placeholder
        var avatarUrl: URL? = nil
        if let template = avatarTemplate {
            let resolvedPath = template.replacingOccurrences(of: "{size}", with: "120")
            if resolvedPath.hasPrefix("http") {
                avatarUrl = URL(string: resolvedPath)
            } else {
                avatarUrl = URL(string: "https://diskussion.piratenpartei.de\(resolvedPath)")
            }
        }

        return UserSearchResult(
            username: username,
            displayName: name,
            avatarUrl: avatarUrl
        )
    }
}

/// A group from the search API (for messageable groups).
struct DiscourseGroupDTO: Decodable {
    let name: String
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
    }
}

// MARK: - POST /posts.json Response DTO

/// Response from Discourse POST /posts.json endpoint when creating a new post/PM.
/// Contains the created post info including the topic_id for navigation.
///
/// API Reference: POST /posts.json
/// - Used for both creating new topics/PMs and replying to existing ones
/// - topic_id is essential for navigating to the newly created thread
struct DiscourseCreatePostResponse: Decodable {
    /// The unique ID of the created post
    let id: Int

    /// The topic ID the post belongs to (needed for navigation)
    let topicId: Int

    /// The sequential post number within the topic
    let postNumber: Int

    /// Username of the post author
    let username: String

    /// Rendered HTML content of the post
    let cooked: String

    /// The URL-friendly slug for the topic (optional)
    let topicSlug: String?

    enum CodingKeys: String, CodingKey {
        case id
        case topicId = "topic_id"
        case postNumber = "post_number"
        case username
        case cooked
        case topicSlug = "topic_slug"
    }
}

// MARK: - GET /u/{username}.json Response DTO

/// Root response from Discourse GET /u/{username}.json endpoint.
/// Contains the full user profile information.
///
/// API Reference: GET /u/{username}.json
struct DiscourseUserProfileResponse: Decodable {
    let user: DiscourseUserProfileDTO
}

/// A full user profile from the Discourse API.
/// Maps to the Domain UserProfile model via toDomainModel().
///
/// Root response from Discourse GET /u/{username}/summary.json endpoint.
/// Contains likes_given and likes_received stats.
struct DiscourseUserSummaryResponse: Decodable {
    let userSummary: DiscourseUserSummaryDTO

    enum CodingKeys: String, CodingKey {
        case userSummary = "user_summary"
    }
}

/// User summary stats from the Discourse API.
struct DiscourseUserSummaryDTO: Decodable {
    let likesGiven: Int?
    let likesReceived: Int?

    enum CodingKeys: String, CodingKey {
        case likesGiven = "likes_given"
        case likesReceived = "likes_received"
    }
}

/// Note: Some stats fields (post_count, like_count, likes_received) may not be
/// available for non-staff users. These are optional with defaults of 0.
struct DiscourseUserProfileDTO: Decodable {
    let id: Int
    let username: String
    let name: String?
    let avatarTemplate: String?
    let bioRaw: String?
    let createdAt: String
    let postCount: Int?
    let likeCount: Int?
    let likesReceived: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case name
        case avatarTemplate = "avatar_template"
        case bioRaw = "bio_raw"
        case createdAt = "created_at"
        case postCount = "post_count"
        case likeCount = "like_count"
        case likesReceived = "likes_received"
    }

    /// Converts this DTO to a domain UserProfile model.
    /// - Returns: UserProfile if all required fields are valid, nil otherwise
    func toDomainModel() -> UserProfile? {
        // Parse the ISO 8601 date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let joinedAt = formatter.date(from: createdAt) else {
            return nil
        }

        // Resolve avatar URL (same pattern as DiscourseUserDTO)
        var avatarUrl: URL?
        if let template = avatarTemplate {
            let resolvedPath = template.replacingOccurrences(of: "{size}", with: "120")
            if resolvedPath.hasPrefix("http") {
                avatarUrl = URL(string: resolvedPath)
            } else {
                avatarUrl = URL(string: "https://diskussion.piratenpartei.de\(resolvedPath)")
            }
        }

        return UserProfile(
            id: id,
            username: username,
            displayName: name,
            avatarUrl: avatarUrl,
            bio: bioRaw,
            joinedAt: joinedAt,
            postCount: postCount ?? 0,
            likesGiven: likeCount ?? 0,
            likesReceived: likesReceived ?? 0
        )
    }
}
