//
//  ProfileView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

/// View displaying the user's profile information and notification settings.
/// Merges SSO data (identity) with Discourse data (avatar, bio, forum stats).
struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @ObservedObject var notificationSettings: NotificationSettingsManager
    var adminRequestViewModelFactory: (() -> AdminRequestViewModel)?
    var checkAdminStatus: (() async -> Bool?)?

    @State private var showAdminRequest = false
    @State private var adminStatus: Bool?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.user == nil {
                    ProgressView("Lade Profil...")
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Erneut versuchen") {
                            viewModel.loadUser()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else if let user = viewModel.user {
                    profileContent(for: user)
                } else {
                    // Fallback when no user data available
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text("Kein Profil verfügbar")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Profil")
            .onAppear {
                if viewModel.user == nil {
                    viewModel.loadUser()
                }
            }
        }
    }

    /// Builds the main profile content view.
    /// - Parameter user: The SSO user data to display
    @ViewBuilder
    private func profileContent(for user: User) -> some View {
        List {
            // Avatar and name section
            Section {
                HStack(spacing: 16) {
                    avatarView
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            user.displayName.lowercased().contains("none")
                                ? (viewModel.discourseProfile?.displayText ?? user.displayName)
                                : user.displayName
                        )
                        .font(.title2)
                        .fontWeight(.semibold)

                        Text("@\(user.username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            
            // Bio section (from Discourse)
            if let bio = viewModel.discourseProfile?.bio, !bio.isEmpty {
                Section("Über mich") {
                    Text(bio)
                        .font(.body)
                }
            }

            // Contact information section (SSO)
            Section("Kontakt") {
                ProfileRow(
                    icon: "envelope",
                    label: "E-Mail",
                    value: user.email
                )
            }

            // Party membership section (SSO)
            Section("Mitgliedschaft") {
                if let memberSince = user.memberSince {
                    ProfileRow(
                        icon: "calendar",
                        label: "Mitglied seit",
                        value: memberSince.formatted(date: .long, time: .omitted)
                    )
                }

                if let localGroup = user.localGroupName {
                    ProfileRow(
                        icon: "mappin.and.ellipse",
                        label: "Kreisverband",
                        value: localGroup
                    )
                }

                if let stateAssociation = user.stateAssociationName {
                    ProfileRow(
                        icon: "building.2",
                        label: "Landesverband",
                        value: stateAssociation
                    )
                }
            }

            // Discourse stats section
            if let profile = viewModel.discourseProfile {
                Section("Aktivität") {
                    ProfileRow(
                        icon: "calendar.badge.clock",
                        label: "Im Forum seit",
                        value: profile.joinedAt.formatted(date: .long, time: .omitted)
                    )
                    ProfileRow(
                        icon: "text.bubble",
                        label: "Beiträge",
                        value: "\(profile.postCount)"
                    )
                    ProfileRow(
                        icon: "heart",
                        label: "Likes vergeben",
                        value: "\(profile.likesGiven)"
                    )
                    ProfileRow(
                        icon: "heart.fill",
                        label: "Likes erhalten",
                        value: "\(profile.likesReceived)"
                    )
                }
            }

            // Notification settings section
            notificationSettingsSection

            // Admin status / request section
            if let status = adminStatus {
                Section("Aufgaben-Verwaltung") {
                    if status {
                        Label("Admin", systemImage: "checkmark.shield.fill")
                            .foregroundColor(.green)
                    } else if adminRequestViewModelFactory != nil {
                        Button {
                            showAdminRequest = true
                        } label: {
                            Label("Admin-Rechte beantragen", systemImage: "person.badge.key")
                        }
                    }
                }
            }

            // Privacy & Info section
            Section {
                NavigationLink {
                    PrivacyView()
                } label: {
                    Label {
                        Text("Datenschutz")
                    } icon: {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.orange)
                    }
                }
            } header: {
                Text("Informationen")
            } footer: {
                Text("Diese App verwendet kein Tracking und keine Analytics.")
            }

            // Discourse load failure note (non-blocking)
            if viewModel.discourseLoadFailed {
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Forum-Statistiken konnten nicht geladen werden.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .task {
            if let check = checkAdminStatus {
                adminStatus = await check()
            }
        }
        .refreshable {
            viewModel.refresh()
            if let check = checkAdminStatus {
                adminStatus = await check()
            }
        }
        .sheet(isPresented: $showAdminRequest) {
            if let factory = adminRequestViewModelFactory {
                AdminRequestView(viewModel: factory())
            }
        }
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarView: some View {
        if let avatarUrl = viewModel.discourseProfile?.avatarUrl {
            AsyncImage(url: avatarUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                case .failure:
                    avatarPlaceholder
                default:
                    ProgressView()
                        .frame(width: 60, height: 60)
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: 60))
            .foregroundColor(.orange)
    }

    // MARK: - Notification Settings

    @ViewBuilder
    private var notificationSettingsSection: some View {
        Section {
            // Messages toggle
            Toggle(isOn: $notificationSettings.messagesEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nachrichten")
                        Text("Bei neuen privaten Nachrichten")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.orange)
                }
            }

            // Todos toggle
            Toggle(isOn: $notificationSettings.todosEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aufgaben")
                        Text("Bei neuen oder geänderten Aufgaben")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "checklist")
                        .foregroundColor(.orange)
                }
            }

            // System permission status (if denied)
            if notificationSettings.authorizationStatus == .denied {
                Button {
                    notificationSettings.openSystemSettings()
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mitteilungen deaktiviert")
                                .foregroundColor(.primary)
                            Text("In den Einstellungen aktivieren")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Mitteilungen")
        } footer: {
            Text("Mitteilungen werden nur für die aktivierten Kategorien gesendet. Es werden keine Nachrichteninhalte übertragen – nur ein allgemeiner Hinweis. Es werden keine Tracking-Daten erfasst.")
                .font(.caption)
        }
    }
}

/// A row displaying a label-value pair with an icon.
/// Used for consistent display of profile information.
private struct ProfileRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Label {
                Text(label)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(.orange)
            }
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    let deviceTokenManager = DeviceTokenManager()
    ProfileView(
        viewModel: ProfileViewModel(
            authRepository: FakeAuthRepository(credentialStore: KeychainCredentialStore()),
            discourseRepository: FakeDiscourseRepository()
        ),
        notificationSettings: NotificationSettingsManager(deviceTokenManager: deviceTokenManager)
    )
}
