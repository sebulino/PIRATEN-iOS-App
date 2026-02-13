//
//  RecipientPickerView.swift
//  PIRATEN
//
//  Created by Claude Code on 02.02.26.
//

import SwiftUI

/// View for selecting a message recipient.
/// Shows recent recipients and allows searching for users.
struct RecipientPickerView: View {
    @ObservedObject var viewModel: RecipientPickerViewModel

    /// Callback when a recipient is selected
    var onRecipientSelected: ((UserSearchResult) -> Void)?

    /// Callback when cancel is tapped
    var onCancel: (() -> Void)?

    var body: some View {
        NavigationStack {
            List {
                // Search results section (shown when searching)
                if !viewModel.searchText.isEmpty {
                    searchResultsSection
                } else {
                    // Recent recipients section (shown when not searching)
                    recentRecipientsSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Empfänger wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onCancel?()
                    }
                }
            }
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Benutzername suchen..."
            )
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.performSearch()
            }
            .onAppear {
                viewModel.loadRecentRecipients()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var searchResultsSection: some View {
        if viewModel.isSearching {
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        } else if let error = viewModel.errorMessage {
            Section {
                Text(error)
                    .foregroundColor(.secondary)
            }
        } else if viewModel.searchResults.isEmpty && viewModel.searchText.count >= 2 {
            Section {
                Text("Keine Benutzer gefunden")
                    .foregroundColor(.secondary)
            }
        } else {
            Section("Suchergebnisse") {
                ForEach(viewModel.searchResults) { user in
                    RecipientRow(user: user)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onRecipientSelected?(user)
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var recentRecipientsSection: some View {
        if viewModel.recentRecipients.isEmpty {
            Section {
                Text("Gib einen Benutzernamen ein, um nach Empfängern zu suchen.")
                    .foregroundColor(.secondary)
            }
        } else {
            Section("Zuletzt kontaktiert") {
                ForEach(viewModel.recentRecipients) { user in
                    RecipientRow(user: user)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onRecipientSelected?(user)
                        }
                }
            }
        }
    }
}

/// Row displaying a single recipient option.
private struct RecipientRow: View {
    let user: UserSearchResult

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with initials
            ZStack {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 40, height: 40)

                Text(initials)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            // Name and username
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayText)
                    .font(.body)
                    .foregroundColor(.primary)

                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    /// Generates initials from display name or username.
    private var initials: String {
        let name = user.displayName ?? user.username
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].first ?? Character(" ")
            let second = components[1].first ?? Character(" ")
            return "\(first)\(second)".uppercased()
        } else if let firstChar = name.first {
            return String(firstChar).uppercased()
        }
        return "?"
    }

    /// Generates a consistent color from the username.
    private var avatarColor: Color {
        let hash = user.username.hashValue
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo]
        return colors[abs(hash) % colors.count]
    }
}

#Preview {
    RecipientPickerView(
        viewModel: RecipientPickerViewModel(
            discourseRepository: FakeDiscourseRepository(),
            recentRecipientsStorage: RecentRecipientsStore()
        )
    )
}
