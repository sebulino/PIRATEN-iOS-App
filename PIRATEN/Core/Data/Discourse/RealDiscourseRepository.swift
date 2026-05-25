//
//  RealDiscourseRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

/// Real implementation of DiscourseRepository that fetches data from the Discourse API.
/// Uses DiscourseAPIClient for authenticated HTTP requests.
///
/// This repository maps API DTOs to domain models and handles errors appropriately.
@MainActor
final class RealDiscourseRepository: DiscourseRepository {

    // MARK: - Dependencies

    private let apiClient: DiscourseAPIClient

    // MARK: - Initialization

    /// Creates a RealDiscourseRepository with the given API client.
    /// - Parameter apiClient: The Discourse API client for making authenticated requests
    init(apiClient: DiscourseAPIClient) {
        self.apiClient = apiClient
    }

    // MARK: - DiscourseRepository

    func fetchTopics() async throws -> [Topic] {
        do {
            let data = try await apiClient.fetchLatest()
            let response = try decodeLatestResponse(from: data)

            // Map DTOs to domain models, filtering out deleted/invisible topics
            let topics = response.topicList.topics.compactMap { dto in
                dto.toDomainModel(users: response.users)
            }.filter { $0.isVisible }

            return topics
        } catch let error as DiscourseError {
            throw mapToRepositoryError(error)
        } catch {
            throw DiscourseRepositoryError.loadFailed(
                message: "Themen konnten nicht geladen werden"
            )
        }
    }

    func fetchPosts(forTopicId topicId: Int) async throws -> [Post] {
        do {
            // Fetch the topic with all posts in a single request (print=true)
            let data = try await apiClient.fetchTopic(id: topicId, includeAllPosts: true)
            let response = try decodeTopicDetailResponse(from: data)

            var allPostDTOs = response.postStream.posts
            let loadedIds = Set(allPostDTOs.map { $0.id })

            // Check if there are more posts to fetch via the stream
            if let stream = response.postStream.stream {
                let missingIds = stream.filter { !loadedIds.contains($0) }
                if !missingIds.isEmpty {
                    // Fetch missing posts in batches of 20 (Discourse limit)
                    for batch in stride(from: 0, to: missingIds.count, by: 20) {
                        let end = min(batch + 20, missingIds.count)
                        let batchIds = Array(missingIds[batch..<end])
                        let batchData = try await apiClient.fetchPostsByIds(
                            topicId: topicId,
                            postIds: batchIds
                        )
                        let batchResponse = try decodePostsByIdsResponse(from: batchData)
                        allPostDTOs.append(contentsOf: batchResponse.postStream.posts)
                    }
                }
            }

            // Sort by post number and map to domain models
            allPostDTOs.sort { $0.postNumber < $1.postNumber }
            let posts = allPostDTOs.compactMap { dto in
                dto.toDomainModel()
            }

            return posts
        } catch let error as DiscourseError {
            throw mapToRepositoryError(error)
        } catch let error as DiscourseRepositoryError {
            throw error
        } catch {
            throw DiscourseRepositoryError.loadFailed(
                message: "Beiträge konnten nicht geladen werden"
            )
        }
    }

    func fetchTopic(byId id: Int) async throws -> Topic {
        do {
            let data = try await apiClient.fetchTopic(id: id)
            let response = try decodeTopicDetailResponse(from: data)

            // Get the first post's author as the topic creator
            guard let firstPost = response.postStream.posts.first,
                  let firstPostDomain = firstPost.toDomainModel(),
                  let topic = response.toDomainModel(firstPostAuthor: firstPostDomain.author) else {
                throw DiscourseRepositoryError.loadFailed(
                    message: "Thema konnte nicht verarbeitet werden"
                )
            }

            return topic
        } catch let error as DiscourseError {
            throw mapToRepositoryError(error)
        } catch let error as DiscourseRepositoryError {
            throw error
        } catch {
            throw DiscourseRepositoryError.loadFailed(
                message: "Thema konnte nicht geladen werden"
            )
        }
    }

    func fetchMessageThreads(for username: String, includeSent: Bool) async throws -> [MessageThread] {
        do {
            if includeSent {
                // Fetch inbox and sent in parallel, then dedupe + merge by ID
                async let inboxDataTask = apiClient.fetchPrivateMessages(for: username)
                async let sentDataTask = apiClient.fetchSentPrivateMessages(for: username)

                let inboxData = try await inboxDataTask
                let sentData = try await sentDataTask

                let inboxResponse = try decodePrivateMessagesResponse(from: inboxData)
                let sentResponse = try decodePrivateMessagesResponse(from: sentData)

                let inboxThreads = inboxResponse.topicList.topics.compactMap { dto in
                    dto.toDomainModel(users: inboxResponse.users)
                }
                let sentThreads = sentResponse.topicList.topics.compactMap { dto in
                    dto.toDomainModel(users: sentResponse.users)
                }

                var seenIds = Set<Int>()
                var mergedThreads: [MessageThread] = []
                for thread in inboxThreads where !seenIds.contains(thread.id) {
                    seenIds.insert(thread.id)
                    mergedThreads.append(thread)
                }
                for thread in sentThreads where !seenIds.contains(thread.id) {
                    seenIds.insert(thread.id)
                    mergedThreads.append(thread)
                }

                mergedThreads.sort { $0.lastActivityAt > $1.lastActivityAt }
                return mergedThreads
            } else {
                let inboxData = try await apiClient.fetchPrivateMessages(for: username)
                let inboxResponse = try decodePrivateMessagesResponse(from: inboxData)
                var inboxThreads = inboxResponse.topicList.topics.compactMap { dto in
                    dto.toDomainModel(users: inboxResponse.users)
                }
                inboxThreads.sort { $0.lastActivityAt > $1.lastActivityAt }
                return inboxThreads
            }
        } catch let error as DiscourseError {
            throw mapToRepositoryError(error)
        } catch {
            throw DiscourseRepositoryError.loadFailed(
                message: "Nachrichten konnten nicht geladen werden"
            )
        }
    }

    func replyToThread(topicId: Int, content: String) async throws {
        do {
            // The API returns the created post, but we don't need to parse it
            // The caller will refresh the thread to get the updated posts list
            _ = try await apiClient.replyToMessageThread(topicId: topicId, content: content)
        } catch let error as DiscourseError {
            throw mapToRepositoryError(error)
        } catch {
            throw DiscourseRepositoryError.loadFailed(
                message: "Nachricht konnte nicht gesendet werden"
            )
        }
    }

    func replyToForumPost(topicId: Int, content: String, replyToPostNumber: Int?) async throws {
        do {
            // The API returns the created post, but we don't need to parse it
            // The caller will refresh the topic to get the updated posts list
            _ = try await apiClient.replyToForumPost(
                topicId: topicId,
                content: content,
                replyToPostNumber: replyToPostNumber
            )
        } catch let error as DiscourseError {
            throw mapToRepositoryError(error)
        } catch {
            throw DiscourseRepositoryError.loadFailed(
                message: "Antwort konnte nicht gesendet werden"
            )
        }
    }

    func searchUsers(query: String) async throws -> [UserSearchResult] {
        // Enforce minimum query length
        guard query.count >= 2 else {
            return []
        }

        do {
            let data = try await apiClient.searchUsers(query: query)
            let response = try decodeUserSearchResponse(from: data)

            // Map DTOs to domain models
            let users = response.users.map { dto in
                dto.toDomainModel()
            }

            return users
        } catch let error as DiscourseError {
            throw mapToRepositoryError(error)
        } catch {
            throw DiscourseRepositoryError.loadFailed(
                message: "Benutzersuche fehlgeschlagen"
            )
        }
    }

    func createPrivateMessage(recipient: String, title: String, content: String) async throws -> Int {
        do {
            let data = try await apiClient.createPrivateMessage(
                recipient: recipient,
                title: title,
                content: content
            )
            let response = try decodeCreatePostResponse(from: data)
            return response.topicId
        } catch let error as DiscourseError {
            throw mapToRepositoryError(error)
        } catch let error as DiscourseRepositoryError {
            throw error
        } catch {
            throw DiscourseRepositoryError.loadFailed(
                message: "Nachricht konnte nicht erstellt werden"
            )
        }
    }

    // MARK: - Likes (OPEN-02 / FR-FORUM-004 strategy chain)

    /// UserDefaults key caching the identifier of the strategy that last
    /// successfully persisted a like. On subsequent calls we try the
    /// cached winner first to avoid re-discovering it on every like.
    private static let winningLikeStrategyKey = "discourse_like_winning_strategy"

    /// Clears the cached "winning strategy" identifier. Called on logout
    /// so the next user on this device does not inherit the previous
    /// user's strategy preference (security audit H-2 — strategy cache
    /// is not itself sensitive, but the logout fan-out should be exhaustive
    /// to avoid future drift between "what we clear" and "what we store").
    static func clearLikeStrategyCache() {
        UserDefaults.standard.removeObject(forKey: winningLikeStrategyKey)
    }

    func likePost(id: Int) async throws {
        try await runStrategyChain(
            postId: id,
            errorMessage: "Gefällt mir konnte nicht gesetzt werden",
            invoke: { strategy in try await strategy.like(postId: id, via: apiClient) }
        )
    }

    func unlikePost(id: Int) async throws {
        try await runStrategyChain(
            postId: id,
            errorMessage: "Gefällt mir konnte nicht entfernt werden",
            invoke: { strategy in try await strategy.unlike(postId: id, via: apiClient) }
        )
    }

    /// Walks `LikeStrategyRegistry.all` in order, trying each strategy
    /// until one returns `true` (server confirmed the action). The
    /// winning strategy is cached so subsequent likes try it first.
    ///
    /// On a "soft failure" (strategy returns `false` — server replied
    /// 2xx but the action did not persist, OPEN-02's signature), we
    /// move to the next strategy. Hard errors (4xx/5xx, transport
    /// failures) abort the chain immediately so we don't mask a
    /// genuine auth or network problem.
    private func runStrategyChain(
        postId: Int,
        errorMessage: String,
        invoke: (LikeStrategy) async throws -> Bool
    ) async throws {
        let registry = LikeStrategyRegistry.all
        guard !registry.isEmpty else {
            throw DiscourseRepositoryError.loadFailed(
                message: "\(errorMessage) (Konfigurationsfehler: keine Strategie aktiv)"
            )
        }

        let cachedWinner = UserDefaults.standard.string(forKey: Self.winningLikeStrategyKey)
        let ordered = orderedStrategies(prioritizing: cachedWinner, in: registry)

        for strategy in ordered {
            do {
                let confirmed = try await invoke(strategy)
                if confirmed {
                    UserDefaults.standard.set(strategy.identifier, forKey: Self.winningLikeStrategyKey)
                    return
                }
                // Soft failure — try the next one.
            } catch let error as DiscourseError {
                throw mapToRepositoryError(error)
            } catch {
                throw DiscourseRepositoryError.loadFailed(message: errorMessage)
            }
        }

        // Every strategy returned `false` — the server accepted each
        // request but never persisted the action. This is the OPEN-02
        // condition surfacing as an explicit failure rather than a
        // silent UI lie.
        throw DiscourseRepositoryError.loadFailed(message: errorMessage)
    }

    /// Returns the strategy chain with the cached winner moved to the
    /// front. If the cached identifier is no longer in the registry
    /// (e.g. you removed it from `LikeStrategyRegistry.all`), falls
    /// back to the registry's natural order.
    private func orderedStrategies(prioritizing cachedId: String?, in registry: [LikeStrategy]) -> [LikeStrategy] {
        guard let cachedId,
              let winnerIndex = registry.firstIndex(where: { $0.identifier == cachedId }) else {
            return registry
        }
        var reordered = registry
        let winner = reordered.remove(at: winnerIndex)
        reordered.insert(winner, at: 0)
        return reordered
    }

    func markTopicAsRead(topicId: Int, highestPostNumber: Int) async throws {
        do {
            try await apiClient.markTopicAsRead(topicId: topicId, highestPostNumber: highestPostNumber)
        } catch let error as DiscourseError {
            throw mapToRepositoryError(error)
        } catch let error as DiscourseRepositoryError {
            throw error
        } catch {
            throw DiscourseRepositoryError.loadFailed(
                message: "Thema konnte nicht als gelesen markiert werden"
            )
        }
    }

    func archiveMessageThread(topicId: Int) async throws {
        do {
            try await apiClient.archiveMessageThread(topicId: topicId)
        } catch let error as DiscourseError {
            throw mapToRepositoryError(error)
        } catch let error as DiscourseRepositoryError {
            throw error
        } catch {
            throw DiscourseRepositoryError.loadFailed(
                message: "Nachricht konnte nicht archiviert werden"
            )
        }
    }

    func fetchUserProfile(username: String) async throws -> UserProfile {
        do {
            let data = try await apiClient.fetchUserProfile(username: username)
            let response = try decodeUserProfileResponse(from: data)

            // Map DTO to domain model
            guard var profile = response.user.toDomainModel() else {
                throw DiscourseRepositoryError.loadFailed(
                    message: "Benutzerprofil konnte nicht verarbeitet werden"
                )
            }

            // Fetch likes from summary endpoint (public, uses URLSession directly
            // to avoid credential-clearing side effects of DiscourseHTTPClient).
            if let summaryData = await apiClient.fetchUserSummary(username: username),
               let summary = try? decodeUserSummaryResponse(from: summaryData) {
                profile = UserProfile(
                    id: profile.id,
                    username: profile.username,
                    displayName: profile.displayName,
                    avatarUrl: profile.avatarUrl,
                    bio: profile.bio,
                    joinedAt: profile.joinedAt,
                    postCount: profile.postCount,
                    likesGiven: summary.userSummary.likesGiven ?? profile.likesGiven,
                    likesReceived: summary.userSummary.likesReceived ?? profile.likesReceived,
                    gliederung: profile.gliederung
                )
            }

            return profile
        } catch let error as DiscourseError {
            throw mapToRepositoryError(error)
        } catch let error as DiscourseRepositoryError {
            throw error
        } catch {
            throw DiscourseRepositoryError.loadFailed(
                message: "Benutzerprofil konnte nicht geladen werden"
            )
        }
    }

    // MARK: - Private Helpers

    /// Decodes the /latest.json response.
    private func decodeLatestResponse(from data: Data) throws -> DiscourseLatestResponse {
        let decoder = JSONDecoder()
        // Note: CodingKeys handle snake_case mapping
        do {
            return try decoder.decode(DiscourseLatestResponse.self, from: data)
        } catch {
            throw DiscourseError.decodingError(message: error.localizedDescription)
        }
    }

    /// Decodes the /t/{topic_id}.json response.
    private func decodeTopicDetailResponse(from data: Data) throws -> DiscourseTopicDetailResponse {
        let decoder = JSONDecoder()
        // Note: CodingKeys handle snake_case mapping
        do {
            return try decoder.decode(DiscourseTopicDetailResponse.self, from: data)
        } catch {
            throw DiscourseError.decodingError(message: error.localizedDescription)
        }
    }

    /// Decodes the /t/{topic_id}/posts.json?post_ids[]=... response.
    private func decodePostsByIdsResponse(from data: Data) throws -> DiscoursePostsByIdsResponse {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(DiscoursePostsByIdsResponse.self, from: data)
        } catch {
            throw DiscourseError.decodingError(message: error.localizedDescription)
        }
    }

    /// Decodes the /topics/private-messages/{username}.json response.
    private func decodePrivateMessagesResponse(from data: Data) throws -> DiscoursePrivateMessagesResponse {
        let decoder = JSONDecoder()
        // Note: CodingKeys handle snake_case mapping
        do {
            return try decoder.decode(DiscoursePrivateMessagesResponse.self, from: data)
        } catch {
            throw DiscourseError.decodingError(message: error.localizedDescription)
        }
    }

    /// Decodes the /u/search/users.json response.
    private func decodeUserSearchResponse(from data: Data) throws -> DiscourseUserSearchResponse {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(DiscourseUserSearchResponse.self, from: data)
        } catch {
            throw DiscourseError.decodingError(message: error.localizedDescription)
        }
    }

    /// Decodes the POST /posts.json response (for creating posts/PMs).
    private func decodeCreatePostResponse(from data: Data) throws -> DiscourseCreatePostResponse {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(DiscourseCreatePostResponse.self, from: data)
        } catch {
            throw DiscourseError.decodingError(message: error.localizedDescription)
        }
    }

    /// Decodes the GET /u/{username}.json response.
    private func decodeUserProfileResponse(from data: Data) throws -> DiscourseUserProfileResponse {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(DiscourseUserProfileResponse.self, from: data)
        } catch {
            throw DiscourseError.decodingError(message: error.localizedDescription)
        }
    }

    /// Decodes the GET /u/{username}/summary.json response.
    private func decodeUserSummaryResponse(from data: Data) throws -> DiscourseUserSummaryResponse {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(DiscourseUserSummaryResponse.self, from: data)
        } catch {
            throw DiscourseError.decodingError(message: error.localizedDescription)
        }
    }

    /// Maps DiscourseError to DiscourseRepositoryError for the domain layer.
    private func mapToRepositoryError(_ error: DiscourseError) -> DiscourseRepositoryError {
        switch error {
        case .unauthorized:
            return .notAuthenticated
        case .forbidden:
            return .notAuthenticated
        case .notFound, .rateLimited, .serverError, .networkError, .decodingError, .cancelled, .unknown:
            return .loadFailed(message: error.localizedDescription)
        }
    }
}
