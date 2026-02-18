//
//  ForumView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct ForumView: View {
    @ObservedObject var viewModel: ForumViewModel
    @ObservedObject var discourseAuthCoordinator: DiscourseAuthCoordinator

    /// Optional callback for when user taps login button in unauthenticated state
    var onLoginTapped: (() -> Void)?

    /// Factory for creating TopicDetailViewModels
    var topicDetailViewModelFactory: ((Topic) -> TopicDetailViewModel)?

    /// Factory for creating UserProfileViewModels
    var userProfileViewModelFactory: ((String) -> UserProfileViewModel)?

    /// Callback when user taps "Nachricht senden" from a profile
    var onSendMessageFromProfile: ((UserProfile) -> Void)?

    /// Callback when user taps the profile toolbar button
    var onProfileTapped: (() -> Void)?

    /// Callback when user taps the notifications toolbar button
    var onNotificationsTapped: (() -> Void)?

    /// Whether to show a badge on the notification bell
    var notificationsBadge: Bool = false

    /// The current window for presenting auth session
    @Environment(\.window) private var window: UIWindow?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadState {
                case .idle, .loading:
                    if viewModel.topics.isEmpty {
                        ProgressView("Lade Themen...")
                    } else {
                        // Show existing topics while refreshing
                        topicsList
                    }

                case .loaded:
                    if viewModel.topics.isEmpty {
                        emptyState
                    } else {
                        topicsList
                    }

                case .notAuthenticated:
                    notAuthenticatedState

                case .authenticationFailed(let message):
                    authenticationFailedState(message: message)

                case .error(let message):
                    errorState(message: message)
                }
            }
            .navigationTitle("Forum")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        onNotificationsTapped?()
                    } label: {
                        Image(systemName: notificationsBadge ? "bell.badge" : "bell")
                    }
                    .accessibilityLabel("Benachrichtigungen")

                    Button {
                        onProfileTapped?()
                    } label: {
                        Image(systemName: "person.circle")
                    }
                    .accessibilityLabel("Profil")
                }
            }
            .onAppear {
                if viewModel.loadState == .idle {
                    viewModel.loadTopics()
                }
            }
        }
    }

    // MARK: - State Views

    /// Topics list using ScrollView + LazyVStack instead of List to avoid
    /// UICollectionView cell dequeue crashes (AttributeGraph cycles).
    @ViewBuilder
    private var topicsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.topics) { topic in
                    if let factory = topicDetailViewModelFactory {
                        NavigationLink {
                            TopicDetailView(
                                viewModel: factory(topic),
                                onLoginTapped: onLoginTapped,
                                userProfileViewModelFactory: userProfileViewModelFactory,
                                onSendMessageFromProfile: onSendMessageFromProfile
                            )
                        } label: {
                            TopicRow(topic: topic)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        TopicRow(topic: topic)
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
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Keine Themen")
                .font(.headline)
            Text("Es wurden noch keine Themen gepostet.")
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
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text("Forum verbinden")
                    .font(.headline)
                Text("Um das Forum zu nutzen, muss die App mit dem Discourse-Forum verbunden werden.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if case .failed(let message) = discourseAuthCoordinator.authState {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
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
                Text("Verbindung wird hergestellt...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

            case .authenticated:
                // This state triggers a reload
                ProgressView()
                    .onAppear {
                        viewModel.loadTopics()
                    }
            }
        }
        .padding()
        .onChange(of: discourseAuthCoordinator.authState) { oldState, newState in
            if newState == .authenticated {
                // Reset coordinator and reload topics
                discourseAuthCoordinator.reset()
                viewModel.loadTopics()
            }
        }
    }

    @ViewBuilder
    private func authenticationFailedState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.lock")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Forum nicht verfügbar")
                .font(.headline)
            Text("Die Verbindung zum Forum konnte nicht hergestellt werden. Die Forum-Authentifizierung wird noch konfiguriert.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") {
                viewModel.loadTopics()
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
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Fehler beim Laden")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") {
                viewModel.loadTopics()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

/// Row view for displaying a single topic in the list.
/// Shows topic title, author, and metadata.
private struct TopicRow: View {
    let topic: Topic

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(topic.title)
                .font(.headline)
                .lineLimit(2)

            HStack {
                // Author name
                Text(topic.createdBy.displayName ?? topic.createdBy.username)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                // Reply count (postsCount includes the original post, so subtract 1)
                Label("\(max(0, topic.postsCount - 1))", systemImage: "bubble.left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(max(0, topic.postsCount - 1)) Antworten")

                // View count
                Label("\(topic.viewCount)", systemImage: "eye")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(topic.viewCount) Aufrufe")
            }

            // Time ago
            Text(topic.createdAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    // Preview with fake data - uses FakeDiscourseRepository
    let credentialStore = InMemoryCredentialStore()
    let fakeRepo = FakeDiscourseRepository()
    let discourseAPIKeyProvider = KeychainDiscourseAPIKeyProvider(credentialStore: credentialStore)

    ForumView(
        viewModel: ForumViewModel(discourseRepository: fakeRepo),
        discourseAuthCoordinator: DiscourseAuthCoordinator(
            discourseAuthManager: nil,
            discourseAPIKeyProvider: discourseAPIKeyProvider,
            credentialStore: credentialStore
        ),
        topicDetailViewModelFactory: { topic in
            TopicDetailViewModel(topic: topic, discourseRepository: fakeRepo)
        }
    )
}
