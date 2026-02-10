//
//  UserProfileTests.swift
//  PIRATENTests
//
//  Created by Claude Code on 10.02.26.
//

import XCTest
@testable import PIRATEN

@MainActor
final class UserProfileTests: XCTestCase {

    // MARK: - UserProfile Tests

    func testDisplayText_PreferDisplayName() {
        // Given a profile with both display name and username
        let profile = UserProfile(
            id: 1,
            username: "testuser",
            displayName: "Test User",
            avatarUrl: nil,
            bio: nil,
            joinedAt: Date(),
            postCount: 0,
            likesGiven: 0,
            likesReceived: 0
        )

        // Then displayText should prefer display name
        XCTAssertEqual(profile.displayText, "Test User")
    }

    func testDisplayText_FallbackToUsername() {
        // Given a profile with no display name
        let profile = UserProfile(
            id: 1,
            username: "testuser",
            displayName: nil,
            avatarUrl: nil,
            bio: nil,
            joinedAt: Date(),
            postCount: 0,
            likesGiven: 0,
            likesReceived: 0
        )

        // Then displayText should fall back to username
        XCTAssertEqual(profile.displayText, "testuser")
    }

    // MARK: - DTO Mapping Tests

    func testDiscourseUserProfileDTO_ToDomainModel_Success() {
        // Given a valid DTO
        let dto = DiscourseUserProfileDTO(
            id: 42,
            username: "nautilus",
            name: "Nautilus Navigator",
            avatarTemplate: "/user_avatar/forum.example.com/nautilus/{size}/123.png",
            bioRaw: "Test bio",
            createdAt: "2025-01-15T10:30:00.000Z",
            postCount: 150,
            likeCount: 75,
            likesReceived: 200
        )

        // When mapping to domain model
        let profile = dto.toDomainModel()

        // Then it should succeed
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.id, 42)
        XCTAssertEqual(profile?.username, "nautilus")
        XCTAssertEqual(profile?.displayName, "Nautilus Navigator")
        XCTAssertEqual(profile?.bio, "Test bio")
        XCTAssertEqual(profile?.postCount, 150)
        XCTAssertEqual(profile?.likesGiven, 75)
        XCTAssertEqual(profile?.likesReceived, 200)
        XCTAssertNotNil(profile?.avatarUrl)
        XCTAssertTrue(profile?.avatarUrl?.absoluteString.contains("120") ?? false)
    }

    func testDiscourseUserProfileDTO_ToDomainModel_MissingStats() {
        // Given a DTO with nil stats (non-staff user)
        let dto = DiscourseUserProfileDTO(
            id: 42,
            username: "nautilus",
            name: "Nautilus",
            avatarTemplate: nil,
            bioRaw: nil,
            createdAt: "2025-01-15T10:30:00.000Z",
            postCount: nil,
            likeCount: nil,
            likesReceived: nil
        )

        // When mapping to domain model
        let profile = dto.toDomainModel()

        // Then it should succeed with default 0 values
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.postCount, 0)
        XCTAssertEqual(profile?.likesGiven, 0)
        XCTAssertEqual(profile?.likesReceived, 0)
    }

    func testDiscourseUserProfileDTO_ToDomainModel_InvalidDate() {
        // Given a DTO with invalid date
        let dto = DiscourseUserProfileDTO(
            id: 42,
            username: "nautilus",
            name: nil,
            avatarTemplate: nil,
            bioRaw: nil,
            createdAt: "invalid-date",
            postCount: nil,
            likeCount: nil,
            likesReceived: nil
        )

        // When mapping to domain model
        let profile = dto.toDomainModel()

        // Then it should fail
        XCTAssertNil(profile)
    }

    // MARK: - ViewModel Tests

    func testUserProfileViewModel_LoadProfile_Success() async {
        // Given a ViewModel with fake repository
        let fakeRepo = FakeDiscourseRepository()
        let viewModel = UserProfileViewModel(username: "nautilus", discourseRepository: fakeRepo)

        // When loading profile
        viewModel.loadProfile()

        // Wait for async operation
        try? await Task.sleep(nanoseconds: 600_000_000)

        // Then state should be loaded
        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertNotNil(viewModel.profile)
        XCTAssertEqual(viewModel.profile?.username, "nautilus")
    }

    func testUserProfileViewModel_Retry() async {
        // Given a ViewModel
        let fakeRepo = FakeDiscourseRepository()
        let viewModel = UserProfileViewModel(username: "nautilus", discourseRepository: fakeRepo)

        // When calling retry
        viewModel.retry()

        // Wait for async operation
        try? await Task.sleep(nanoseconds: 600_000_000)

        // Then it should load the profile
        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertNotNil(viewModel.profile)
    }

    func testUserProfileViewModel_InitialState() async {
        // Given a new ViewModel
        let fakeRepo = FakeDiscourseRepository()
        let viewModel = UserProfileViewModel(username: "nautilus", discourseRepository: fakeRepo)

        // Then initial state should be idle
        XCTAssertEqual(viewModel.loadState, .idle)
        XCTAssertNil(viewModel.profile)
        XCTAssertEqual(viewModel.username, "nautilus")
    }
}
