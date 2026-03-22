//
//  UserProfileView.swift
//  PIRATEN
//
//  Created by Claude Code on 10.02.26.
//

import SwiftUI

/// Displays a full user profile with avatar, bio, stats, and messaging action.
/// Presented as a modal sheet from tappable usernames in forum posts and messages.
///
/// ## Layout
/// - Profile header (large avatar, display name, @username)
/// - Stats section (join date, posts, likes given/received)
/// - Bio section (if present)
/// - "Nachricht senden" button (safeAreaInset at bottom)
///
/// ## Load States
/// Handles: idle, loading, loaded, notAuthenticated, authenticationFailed, error
struct UserProfileView: View {

    // MARK: - Dependencies

    @ObservedObject var viewModel: UserProfileViewModel

    // MARK: - Callbacks

    /// Called when the user taps "Zum Login" from not authenticated state
    let onLoginTapped: () -> Void

    /// Called when the user taps "Nachricht senden" button with the loaded profile
    let onSendMessageTapped: (UserProfile) -> Void

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                switch viewModel.loadState {
                case .idle:
                    Color.clear
                        .onAppear {
                            viewModel.loadProfile()
                        }

                case .loading:
                    ProgressView("Lade Profil...")
                        .progressViewStyle(.circular)

                case .loaded:
                    if let profile = viewModel.profile {
                        profileContent(profile: profile)
                    } else {
                        errorContent(message: "Profil konnte nicht geladen werden")
                    }

                case .notAuthenticated:
                    notAuthenticatedContent

                case .authenticationFailed(let message):
                    authenticationFailedContent(message: message)

                case .error(let message):
                    errorContent(message: message)
                }
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Profile Content

    @ViewBuilder
    private func profileContent(profile: UserProfile) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header
                VStack(spacing: 12) {
                    // Large avatar
                    if let avatarUrl = profile.avatarUrl {
                        AsyncImage(url: avatarUrl) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            initialsAvatar(for: profile)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .accessibilityHidden(true)
                    } else {
                        initialsAvatar(for: profile)
                            .accessibilityHidden(true)
                    }

                    // Display name
                    Text(profile.displayText)
                        .font(.piratenTitle2)
                        .fontWeight(.bold)

                    // @username
                    Text("@\(profile.username)")
                        .font(.piratenSubheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                // Stats Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Statistiken")
                        .font(.piratenHeadlineBody)
                        .foregroundColor(.primary)

                    VStack(spacing: 8) {
                        statsRow(label: "Mitglied seit", value: formatJoinDate(profile.joinedAt))
                        statsRow(label: "Beiträge", value: "\(profile.postCount)")
                        statsRow(label: "Likes gegeben", value: "\(profile.likesGiven)")
                        statsRow(label: "Likes erhalten", value: "\(profile.likesReceived)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                // Gliederung Section
                if let gliederung = profile.gliederung, !gliederung.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Gliederung")
                            .font(.piratenHeadlineBody)
                            .foregroundColor(.primary)

                        Text(gliederung)
                            .font(.piratenBodyDefault)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                // Bio Section
                if let bio = profile.bio, !bio.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Bio")
                            .font(.piratenHeadlineBody)
                            .foregroundColor(.primary)

                        Text(bio)
                            .font(.piratenBodyDefault)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                Spacer(minLength: 80) // Space for bottom button
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                onSendMessageTapped(profile)
            } label: {
                Text("Nachricht senden")
                    .font(.piratenHeadlineBody)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.piratenPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func statsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.piratenBodyDefault)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.piratenBodyDefault)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Error States

    @ViewBuilder
    private var notAuthenticatedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Nicht angemeldet")
                .font(.piratenTitle3)
                .fontWeight(.semibold)
            Text("Melde dich an, um Profile anzusehen.")
                .font(.piratenBodyDefault)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Zum Login") {
                onLoginTapped()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @ViewBuilder
    private func authenticationFailedContent(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(Color.piratenPrimary)
                .accessibilityHidden(true)
            Text("Authentifizierung fehlgeschlagen")
                .font(.piratenTitle3)
                .fontWeight(.semibold)
            Text(message)
                .font(.piratenBodyDefault)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Zum Login") {
                onLoginTapped()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @ViewBuilder
    private func errorContent(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 60))
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            Text("Fehler")
                .font(.piratenTitle3)
                .fontWeight(.semibold)
            Text(message)
                .font(.piratenBodyDefault)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") {
                viewModel.retry()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Avatar Helpers

    @ViewBuilder
    private func initialsAvatar(for profile: UserProfile) -> some View {
        ZStack {
            Circle()
                .fill(avatarColor(for: profile.username).opacity(0.3))
                .frame(width: 80, height: 80)
            Text(authorInitials(for: profile))
                .font(.system(.title, weight: .semibold))
                .foregroundStyle(avatarColor(for: profile.username))
        }
    }

    /// Extracts initials from the display name or username
    private func authorInitials(for profile: UserProfile) -> String {
        let name = profile.displayText
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = name.first {
            return String(first).uppercased()
        }
        return "?"
    }

    /// Color for the avatar circle based on username hash
    /// Reused logic from MessagePostRow
    private func avatarColor(for username: String) -> Color {
        let colors: [Color] = [.piratenPrimary, .blue, .green, .purple, .pink, .teal]
        let hash = username.hashValue
        return colors[abs(hash) % colors.count]
    }

    // MARK: - Date Formatting

    private func formatJoinDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
}

// MARK: - Previews

#Preview("Loaded") {
    UserProfileView(
        viewModel: {
            let vm = UserProfileViewModel(
                username: "nautilus",
                discourseRepository: FakeDiscourseRepository()
            )
            vm.loadProfile()
            return vm
        }(),
        onLoginTapped: {},
        onSendMessageTapped: { _ in }
    )
}

#Preview("Loading") {
    UserProfileView(
        viewModel: UserProfileViewModel(
            username: "nautilus",
            discourseRepository: FakeDiscourseRepository()
        ),
        onLoginTapped: {},
        onSendMessageTapped: { _ in }
    )
}
