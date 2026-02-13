//
//  UserProfileViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 10.02.26.
//

import Foundation
import Combine

/// Load state for user profile view.
enum UserProfileLoadState: Equatable {
    case idle
    case loading
    case loaded
    case notAuthenticated
    case authenticationFailed(message: String)
    case error(message: String)
}

/// ViewModel for displaying a user's full profile.
/// Fetches profile data from the DiscourseRepository and manages load state.
@MainActor
final class UserProfileViewModel: ObservableObject {

    // MARK: - Published State

    /// The username to fetch profile for (immutable)
    let username: String

    /// The loaded user profile (nil until loaded)
    @Published private(set) var profile: UserProfile?

    /// Current load state
    @Published private(set) var loadState: UserProfileLoadState = .idle

    // MARK: - Dependencies

    private let discourseRepository: DiscourseRepository

    // MARK: - Initialization

    /// Creates a UserProfileViewModel.
    /// - Parameters:
    ///   - username: The username to fetch the profile for
    ///   - discourseRepository: Repository for fetching user data
    init(username: String, discourseRepository: DiscourseRepository) {
        self.username = username
        self.discourseRepository = discourseRepository
    }

    // MARK: - Public Methods

    /// Loads the user profile from the repository.
    /// Call this when the view appears or when retrying after an error.
    func loadProfile() {
        guard loadState != .loading else { return }

        loadState = .loading
        profile = nil

        Task {
            do {
                let fetchedProfile = try await discourseRepository.fetchUserProfile(username: username)
                
                profile = fetchedProfile
                loadState = .loaded
            } catch let error as DiscourseRepositoryError {
                handleRepositoryError(error)
            } catch {
                loadState = .error(message: "Unbekannter Fehler")
            }
        }
    }

    /// Retries loading the profile after an error.
    /// This is a convenience wrapper around loadProfile() for UI clarity.
    func retry() {
        loadProfile()
    }

    // MARK: - Private Helpers

    private func handleRepositoryError(_ error: DiscourseRepositoryError) {
        switch error {
        case .notAuthenticated:
            loadState = .notAuthenticated
        case .authenticationFailed(let message):
            loadState = .authenticationFailed(message: message)
        case .loadFailed(let message):
            loadState = .error(message: message)
        }
    }
}
