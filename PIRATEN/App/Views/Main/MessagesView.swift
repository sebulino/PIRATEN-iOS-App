//
//  MessagesView.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import SwiftUI

struct MessagesView: View {
    @ObservedObject var viewModel: MessagesViewModel
    @ObservedObject var discourseAuthCoordinator: DiscourseAuthCoordinator

    /// The current window for presenting auth session
    @Environment(\.window) private var window: UIWindow?

    /// Factory for creating MessageThreadDetailViewModels
    var messageThreadDetailViewModelFactory: ((MessageThread) -> MessageThreadDetailViewModel)?

    /// Factory for creating UserProfileViewModels
    var userProfileViewModelFactory: ((String) -> UserProfileViewModel)?

    /// Callback when user taps "Nachricht senden" from a profile
    var onSendMessageFromProfile: ((UserProfile) -> Void)?

    /// Callback for when user taps the compose FAB to create a new message
    var onComposeTapped: (() -> Void)?

    /// Environment dismiss for sheet presentation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Floating Action Button - only visible when authenticated
                if isAuthenticated {
                    composeButton
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // FAB as overlay - doesn't participate in layout, so it can't
            // trigger a layout flush on the List's collection view
            .overlay(alignment: .bottomTrailing) {
                if isAuthenticated {
                    composeButton
                }
            }
            .piratenStyledBackground()
            .navigationTitle("Nachrichten")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Schließen")
                }
            }
            .onAppear {
                if viewModel.loadState == .idle {
                    viewModel.loadMessages()
                }
            }
        }
    }

    // MARK: - Computed Properties

    /// Whether the user is authenticated (FAB should be visible)
    private var isAuthenticated: Bool {
        switch viewModel.loadState {
        case .loaded, .loading, .error:
            // Show FAB when loaded, loading (refresh), or recoverable error
            return true
        case .idle:
            // Show FAB if we have cached threads (implies prior auth)
            return !viewModel.messageThreads.isEmpty
        case .notAuthenticated, .authenticationFailed:
            return false
        }
    }

    // MARK: - Compose Button

    @ViewBuilder
    private var composeButton: some View {
        Button {
            onComposeTapped?()
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.piratenPrimary)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .padding(.trailing, 16)
        .padding(.bottom, 16)
        .accessibilityLabel("Neue Nachricht verfassen")
    }

    // MARK: - State Views

    /// Message threads list using ScrollView + LazyVStack instead of List to avoid
    /// UICollectionView cell dequeue crashes (AttributeGraph cycles).
    @ViewBuilder
    private var messageThreadsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.messageThreads) { thread in
                    if let factory = messageThreadDetailViewModelFactory {
                        NavigationLink {
                            MessageThreadDetailView(
                                viewModel: factory(thread),
                                discourseAuthCoordinator: discourseAuthCoordinator,
                                userProfileViewModelFactory: userProfileViewModelFactory,
                                onSendMessageFromProfile: onSendMessageFromProfile
                            )
                        } label: {
                            MessageThreadRow(thread: thread)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        MessageThreadRow(thread: thread)
                    }
                    Divider()
                        .padding(.leading, 16)
                }
            }
            .padding(.horizontal, 16)
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
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
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
            switch discourseAuthCoordinator.authState {
            case .idle, .failed:
                Image(systemName: "envelope.badge.person.crop")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.piratenPrimary)
                    .accessibilityHidden(true)
                Text("Nachrichten verbinden")
                    .font(.headline)
                Text("Um Nachrichten zu lesen und zu senden, muss die App mit dem Discourse-Forum verbunden werden.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if case .failed(let message) = discourseAuthCoordinator.authState {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button {
                    Task {
                        await discourseAuthCoordinator.authenticate(from: window)
                    }
                } label: {
                    Label("Mit Forum verbinden", systemImage: "link")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!discourseAuthCoordinator.isAuthAvailable)

            case .authenticating:
                ProgressView()
                    .scaleEffect(1.5)
                Text("Verbinde mit Forum...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

            case .authenticated:
                ProgressView()
                Text("Verbunden! Lade Nachrichten...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onChange(of: discourseAuthCoordinator.authState) { oldState, newState in
            if newState == .authenticated {
                discourseAuthCoordinator.reset()
                viewModel.loadMessages()
            }
        }
    }

    @ViewBuilder
    private func authenticationFailedState(message: String) -> some View {
        VStack(spacing: 16) {
            switch discourseAuthCoordinator.authState {
            case .idle, .failed:
                Image(systemName: "exclamationmark.lock")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.piratenPrimary)
                    .accessibilityHidden(true)
                Text("Sitzung abgelaufen")
                    .font(.headline)
                Text("Die Verbindung zu den Nachrichten ist abgelaufen. Bitte erneut verbinden.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if case .failed(let authMessage) = discourseAuthCoordinator.authState {
                    Text(authMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        await discourseAuthCoordinator.authenticate(from: window)
                    }
                } label: {
                    Label("Erneut verbinden", systemImage: "link")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!discourseAuthCoordinator.isAuthAvailable)

            case .authenticating:
                ProgressView()
                    .scaleEffect(1.5)
                Text("Verbindung wird hergestellt...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

            case .authenticated:
                ProgressView()
                Text("Verbunden! Lade Nachrichten...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onChange(of: discourseAuthCoordinator.authState) { oldState, newState in
            if newState == .authenticated {
                discourseAuthCoordinator.reset()
                viewModel.loadMessages()
            }
        }
    }

    @ViewBuilder
    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.piratenPrimary)
                .accessibilityHidden(true)
            Text("Fehler beim Laden")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                    .foregroundStyle(thread.isRead ? .primary : Color.blue)

                Spacer()

                if !thread.isRead {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                        .accessibilityLabel("Ungelesen")
                }
            }

            // Participants
            Text(participantsText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack {
                // Reply count (postsCount includes the original post, so subtract 1)
                Label("\(max(0, thread.postsCount - 1))", systemImage: "bubble.left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(max(0, thread.postsCount - 1)) Antworten")

                Spacer()

                // Last activity time
                Text(thread.lastActivityAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
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
    let discourseAPIKeyProvider = KeychainDiscourseAPIKeyProvider(credentialStore: credentialStore)

    MessagesView(
        viewModel: MessagesViewModel(
            discourseRepository: fakeDiscourseRepo,
            authRepository: fakeAuthRepo
        ),
        discourseAuthCoordinator: DiscourseAuthCoordinator(
            discourseAuthManager: nil,
            discourseAPIKeyProvider: discourseAPIKeyProvider,
            credentialStore: credentialStore
        ),
        messageThreadDetailViewModelFactory: { thread in
            MessageThreadDetailViewModel(thread: thread, discourseRepository: fakeDiscourseRepo)
        },
        onComposeTapped: { }
    )
}
