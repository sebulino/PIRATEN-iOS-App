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

            // Map DTOs to domain models
            let topics = response.topicList.topics.compactMap { dto in
                dto.toDomainModel(users: response.users)
            }

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
            let data = try await apiClient.fetchTopic(id: topicId)
            let response = try decodeTopicDetailResponse(from: data)

            // Map post DTOs to domain models
            // Discourse /t/{id}.json returns posts in post_stream.posts (first 20)
            let posts = response.postStream.posts.compactMap { dto in
                dto.toDomainModel()
            }

            return posts
        } catch let error as DiscourseError {
            throw mapToRepositoryError(error)
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

    func fetchMessageThreads(for username: String) async throws -> [MessageThread] {
        do {
            let data = try await apiClient.fetchPrivateMessages(for: username)
            let response = try decodePrivateMessagesResponse(from: data)

            // Map DTOs to domain models
            let threads = response.topicList.topics.compactMap { dto in
                dto.toDomainModel(users: response.users)
            }

            return threads
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

    /// Maps DiscourseError to DiscourseRepositoryError for the domain layer.
    private func mapToRepositoryError(_ error: DiscourseError) -> DiscourseRepositoryError {
        switch error {
        case .unauthorized:
            return .notAuthenticated
        case .forbidden:
            return .authenticationFailed(message: error.localizedDescription)
        case .notFound, .rateLimited, .serverError, .networkError, .decodingError, .cancelled, .unknown:
            return .loadFailed(message: error.localizedDescription)
        }
    }
}
