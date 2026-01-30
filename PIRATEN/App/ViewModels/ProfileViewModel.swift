//
//  ProfileViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation
import Combine

/// ViewModel for the Profile tab.
/// Coordinates between the ProfileView and the AuthRepository.
/// Provides published state for SwiftUI data binding.
///
/// Note: Currently displays PLACEHOLDER DATA for development.
/// Real user information will come from Piratenlogin SSO once integrated.
@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Published State

    /// The current user's information (placeholder data for now)
    @Published private(set) var user: User?

    /// Whether user data is currently being loaded
    @Published private(set) var isLoading: Bool = false

    /// Error message if loading failed, nil otherwise
    @Published private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let authRepository: AuthRepository

    // MARK: - Initialization

    /// Creates a ProfileViewModel with the given repository.
    /// - Parameter authRepository: The repository to fetch user data from
    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    // MARK: - Public Methods

    /// Loads the current user's profile information from the repository.
    /// Updates published state for loading, user, and errors.
    func loadUser() {
        isLoading = true
        errorMessage = nil

        Task {
            let fetchedUser = await authRepository.getCurrentUser()
            self.user = fetchedUser
            self.isLoading = false
        }
    }

    /// Refreshes the user profile. Alias for loadUser for pull-to-refresh.
    func refresh() {
        loadUser()
    }
}
