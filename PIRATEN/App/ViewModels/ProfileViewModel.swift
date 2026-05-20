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
    ///
    /// Fire-and-forget: spawns a Task and returns immediately. Use this from
    /// `.onAppear` where you don't need the caller to await completion.
    /// For pull-to-refresh, use `refresh()` instead — that variant awaits
    /// the fetch so SwiftUI's `.refreshable` spinner accurately tracks the
    /// actual work duration.
    func loadUser() {
        Task { await refresh() }
    }

    /// Async variant for pull-to-refresh. Returns when the SSO user fetch
    /// AND the Discourse profile fetch have both settled. SwiftUI's
    /// `.refreshable` modifier will keep the spinner visible for exactly
    /// this duration, so the user sees an accurate indicator of work
    /// in progress.
    ///
    /// Previously this was a thin alias around `loadUser()`, which fired a
    /// Task and returned synchronously — meaning the spinner stopped
    /// instantly and the actual refresh happened invisibly. Worse, the
    /// caller (ProfileView's `.refreshable`) was awaiting a *different*
    /// operation (`checkAdminStatus`) that hits a sometimes-slow
    /// meine-piraten.de endpoint, which made the spinner hang for as long
    /// as that admin check took — completely decoupled from the actual
    /// profile data refresh.
    func refresh() async {
        isLoading = true
        errorMessage = nil
        discourseLoadFailed = false
        defer { isLoading = false }

        let fetchedUser = await authRepository.getCurrentUser()
        self.user = fetchedUser

        // Discourse profile is fetched best-effort. Failure flips a flag
        // for the UI to show a non-blocking notice; it does not raise to
        // the caller.
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
