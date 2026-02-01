//
//  MessagesView.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import SwiftUI

struct MessagesView: View {
    @ObservedObject var viewModel: MessagesViewModel

    /// Optional callback for when user taps login button in unauthenticated state
    var onLoginTapped: (() -> Void)?

    /// Factory for creating MessageThreadDetailViewModels
    var messageThreadDetailViewModelFactory: ((MessageThread) -> MessageThreadDetailViewModel)?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadState {
                case .idle, .loading:
                    if viewModel.messageThreads.isEmpty {
                        ProgressView("Lade Nachrichten...")
                    } else {
                        // Show existing threads while refreshing
                        messageThreadsList
                    }

                case .loaded:
                    if viewModel.messageThreads.isEmpty {
                        emptyState
                    } else {
                        messageThreadsList
                    }

                case .notAuthenticated:
                    notAuthenticatedState

                case .authenticationFailed(let message):
                    authenticationFailedState(message: message)

                case .error(let message):
                    errorState(message: message)
                }
            }
            .navigationTitle("Nachrichten")
            .onAppear {
                if viewModel.loadState == .idle {
                    viewModel.loadMessages()
                }
            }
        }
    }

    // MARK: - State Views

    @ViewBuilder
    private var messageThreadsList: some View {
        List(viewModel.messageThreads) { thread in
            if let factory = messageThreadDetailViewModelFactory {
                NavigationLink {
                    MessageThreadDetailView(
                        viewModel: factory(thread),
                        onLoginTapped: onLoginTapped
                    )
                } label: {
                    MessageThreadRow(thread: thread)
                }
            } else {
                MessageThreadRow(thread: thread)
            }
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Keine Nachrichten")
                .font(.headline)
            Text("Du hast noch keine privaten Nachrichten.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Aktualisieren") {
                viewModel.refresh()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    @ViewBuilder
    private var notAuthenticatedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            Text("Anmeldung erforderlich")
                .font(.headline)
            Text("Bitte melde dich an, um deine Nachrichten zu sehen.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Anmelden") {
                onLoginTapped?()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @ViewBuilder
    private func authenticationFailedState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.lock")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Nachrichten nicht verfügbar")
                .font(.headline)
            Text("Die Verbindung zu den Nachrichten konnte nicht hergestellt werden. Die Nachrichten-Authentifizierung wird noch konfiguriert.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") {
                viewModel.loadMessages()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    @ViewBuilder
    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Fehler beim Laden")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") {
                viewModel.loadMessages()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

/// Row view for displaying a single message thread in the list.
/// Shows thread title, participants, last activity, and post count.
private struct MessageThreadRow: View {
    let thread: MessageThread

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(thread.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(thread.isRead ? .primary : .blue)

                Spacer()

                if !thread.isRead {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                }
            }

            // Participants
            Text(participantsText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)

            HStack {
                // Post count
                Label("\(thread.postsCount)", systemImage: "bubble.left")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Last activity time
                Text(thread.lastActivityAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    /// Formatted string of participant names
    private var participantsText: String {
        let names = thread.participants.map { $0.displayName ?? $0.username }
        switch names.count {
        case 0:
            return "Keine Teilnehmer"
        case 1:
            return names[0]
        case 2:
            return "\(names[0]) und \(names[1])"
        default:
            let remaining = names.count - 2
            return "\(names[0]), \(names[1]) und \(remaining) weitere"
        }
    }
}

#Preview {
    // Preview with fake data - uses FakeDiscourseRepository and FakeAuthRepository
    let credentialStore = KeychainCredentialStore()
    let fakeDiscourseRepo = FakeDiscourseRepository()
    let fakeAuthRepo = FakeAuthRepository(credentialStore: credentialStore)

    MessagesView(
        viewModel: MessagesViewModel(
            discourseRepository: fakeDiscourseRepo,
            authRepository: fakeAuthRepo
        ),
        messageThreadDetailViewModelFactory: { thread in
            MessageThreadDetailViewModel(thread: thread, discourseRepository: fakeDiscourseRepo)
        }
    )
}
