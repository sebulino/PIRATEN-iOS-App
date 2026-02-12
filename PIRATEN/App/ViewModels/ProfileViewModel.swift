//
//  ProfileViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation
import Combine

/// ViewModel for the Profile tab.
/// Coordinates between the ProfileView, AuthRepository, and DiscourseRepository.
/// Merges SSO user data with Discourse profile data (avatar, bio, stats).
/// SSO data takes priority when fields conflict.
@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Published State

    /// The current user's information from SSO
    @Published private(set) var user: User?

    /// The user's Discourse profile (avatar, bio, stats)
    @Published private(set) var discourseProfile: UserProfile?

    /// Whether user data is currently being loaded
    @Published private(set) var isLoading: Bool = false

    /// Error message if loading failed, nil otherwise
    @Published private(set) var errorMessage: String?

    /// Whether Discourse profile loading failed (non-blocking)
    @Published private(set) var discourseLoadFailed: Bool = false

    // MARK: - Dependencies

    private let authRepository: AuthRepository
    private let discourseRepository: DiscourseRepository

    // MARK: - Initialization

    /// Creates a ProfileViewModel with the given repositories.
    /// - Parameters:
    ///   - authRepository: The repository to fetch SSO user data from
    ///   - discourseRepository: The repository to fetch Discourse profile data from
    init(authRepository: AuthRepository, discourseRepository: DiscourseRepository) {
        self.authRepository = authRepository
        self.discourseRepository = discourseRepository
    }

    // MARK: - Public Methods

    /// Loads the current user's profile information from SSO and Discourse.
    /// SSO data is required; Discourse data is fetched best-effort.
    func loadUser() {
        isLoading = true
        errorMessage = nil
        discourseLoadFailed = false

        Task {
            let fetchedUser = await authRepository.getCurrentUser()
            self.user = fetchedUser
            self.isLoading = false

            // Fetch Discourse profile if we have a username
            if let username = fetchedUser?.username {
                do {
                    let profile = try await discourseRepository.fetchUserProfile(username: username)
                    self.discourseProfile = profile
                } catch {
                    self.discourseLoadFailed = true
                }
            }
        }
    }

    /// Refreshes the user profile. Alias for loadUser for pull-to-refresh.
    func refresh() {
        loadUser()
    }
}
