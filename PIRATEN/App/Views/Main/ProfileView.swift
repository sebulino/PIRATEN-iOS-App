//
//  ProfileView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

/// View displaying the user's profile information.
///
/// Note: Currently displays PLACEHOLDER DATA for development.
/// Real user information will come from Piratenlogin SSO once integrated.
struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.user == nil {
                    ProgressView("Lade Profil...")
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
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
                            .foregroundColor(.secondary)
                        Text("Kein Profil verfügbar")
                            .font(.headline)
                            .foregroundColor(.secondary)
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
    /// - Parameter user: The user data to display (PLACEHOLDER DATA)
    @ViewBuilder
    private func profileContent(for user: User) -> some View {
        List {
            // Avatar and name section (placeholder data)
            Section {
                HStack(spacing: 16) {
                    // Avatar placeholder
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("@\(user.username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // Contact information section (placeholder data)
            Section("Kontakt") {
                ProfileRow(
                    icon: "envelope",
                    label: "E-Mail",
                    value: user.email
                )
            }

            // Party membership section (placeholder data)
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

            // Note about placeholder data
            Section {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Dies sind Testdaten. Nach der SSO-Integration werden hier Ihre echten Daten angezeigt.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .refreshable {
            viewModel.refresh()
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
    // Preview with fake data - uses FakeAuthRepository via KeychainCredentialStore
    // Note: Requires an authenticated session for user data to display
    ProfileView(viewModel: ProfileViewModel(
        authRepository: FakeAuthRepository(credentialStore: KeychainCredentialStore())
    ))
}
