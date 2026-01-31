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
        // Not implemented in this story - will be implemented in M3B-003
        throw DiscourseRepositoryError.loadFailed(
            message: "Beiträge laden ist noch nicht implementiert"
        )
    }

    func fetchTopic(byId id: Int) async throws -> Topic {
        // Not implemented in this story - will be implemented in M3B-003
        throw DiscourseRepositoryError.loadFailed(
            message: "Einzelnes Thema laden ist noch nicht implementiert"
        )
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
