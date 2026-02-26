//
//  HomeView.swift
//  PIRATEN
//
//  Created by Claude Code on 19.02.26.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel

    /// Factory for creating TopicDetailViewModels (forum topics)
    var topicDetailViewModelFactory: ((Topic) -> TopicDetailViewModel)?

    /// Factory for creating KnowledgeTopicDetailViewModels
    var knowledgeTopicDetailViewModelFactory: ((KnowledgeTopic) -> KnowledgeTopicDetailViewModel)?

    /// Factory for creating UserProfileViewModels
    var userProfileViewModelFactory: ((String) -> UserProfileViewModel)?

    /// Callback when user taps "Nachricht senden" from a contact profile
    var onSendMessageFromProfile: ((UserProfile) -> Void)?

    /// Callback when user taps the profile toolbar button
    var onProfileTapped: (() -> Void)?

    /// Callback when user taps the notifications toolbar button
    var onNotificationsTapped: (() -> Void)?

    /// Whether to show a badge on the notification bell
    var notificationsBadge: Bool = false

    /// Callback when user taps the messages button to open Nachrichten
    var onMessagesTapped: (() -> Void)?

    /// Username of the contact whose profile is being shown
    @State private var selectedContactUsername: String?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadState {
                case .idle, .loading:
                    if viewModel.recentTopics.isEmpty && viewModel.recentContacts.isEmpty {
                        ProgressView("Lade Kajüte...")
                    } else {
                        dashboardContent
                    }

                case .loaded:
                    dashboardContent

                case .error(let message):
                    errorState(message: message)
                }
            }
            .piratenStyledBackground()
            .navigationTitle("Kajüte")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    PiratenIconButton(
                        systemName: "envelope",
                        accessibilityLabel: "Nachrichten"
                    ) {
                        onMessagesTapped?()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 2) {
                        PiratenIconButton(
                            systemName: notificationsBadge ? "bell.badge" : "bell",
                            badge: notificationsBadge,
                            accessibilityLabel: "Benachrichtigungen"
                        ) {
                            onNotificationsTapped?()
                        }

                        PiratenIconButton(
                            systemName: "person.circle",
                            accessibilityLabel: "Profil"
                        ) {
                            onProfileTapped?()
                        }
                    }
                }
            }
            .navigationDestination(for: Topic.self) { topic in
                if let factory = topicDetailViewModelFactory {
                    TopicDetailView(viewModel: factory(topic))
                }
            }
            .onAppear {
                if viewModel.loadState == .idle {
                    viewModel.loadDashboard()
                }
            }
            .sheet(item: Binding(
                get: { selectedContactUsername.map { SelectedUsername(username: $0) } },
                set: { selectedContactUsername = $0?.username }
            )) { selected in
                if let factory = userProfileViewModelFactory {
                    UserProfileView(
                        viewModel: factory(selected.username),
                        onLoginTapped: { selectedContactUsername = nil },
                        onSendMessageTapped: { profile in
                            selectedContactUsername = nil
                            onSendMessageFromProfile?(profile)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private var dashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section 1: Recent Contacts
                recentContactsSection

                // Section 2: Knowledge Articles
                knowledgeSection

                // Section 3: Recent Forum Topics
                recentTopicsSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    // MARK: - Section 1: Recent Contacts

    @ViewBuilder
    private var recentContactsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Letzte Kontakte")
                .font(.headline)

            if viewModel.recentContacts.isEmpty {
                Text("Noch keine Nachrichten")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(viewModel.recentContacts) { contact in
                            Button {
                                selectedContactUsername = contact.username
                            } label: {
                                contactAvatar(contact)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func contactAvatar(_ contact: UserSummary) -> some View {
        VStack(spacing: 4) {
            if let avatarUrl = contact.avatarUrl {
                AsyncImage(url: avatarUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.secondary)
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.secondary)
                    .frame(width: 48, height: 48)
            }

            Text(contact.displayName ?? contact.username)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 56)
        }
    }

    // MARK: - Section 2: Knowledge Articles

    @ViewBuilder
    private var knowledgeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weiterlesen")
                .font(.headline)

            if viewModel.knowledgeArticles.isEmpty {
                Text("Entdecke den Wissensbereich")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.knowledgeArticles) { topic in
                    if let factory = knowledgeTopicDetailViewModelFactory {
                        NavigationLink {
                            KnowledgeTopicDetailView(viewModel: factory(topic))
                        } label: {
                            knowledgeRow(topic)
                        }
                        .buttonStyle(.plain)
                    } else {
                        knowledgeRow(topic)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func knowledgeRow(_ topic: KnowledgeTopic) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(topic.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Text(topic.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Section 3: Recent Forum Topics

    @ViewBuilder
    private var recentTopicsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aktuelle Themen")
                .font(.headline)

            if viewModel.recentTopics.isEmpty {
                Text("Keine Themen verfügbar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.recentTopics) { topic in
                    if topicDetailViewModelFactory != nil {
                        NavigationLink(value: topic) {
                            forumTopicRow(topic)
                        }
                        .buttonStyle(.plain)
                    } else {
                        forumTopicRow(topic)
                    }
                    if topic.id != viewModel.recentTopics.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func forumTopicRow(_ topic: Topic) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(topic.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)

            HStack(spacing: 12) {
                Label("\(max(0, topic.postsCount - 1))", systemImage: "bubble.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(topic.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Error State

    @ViewBuilder
    private func errorState(message: String) -> some View {
        ContentUnavailableView {
            Label("Fehler", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Erneut versuchen") {
                viewModel.refresh()
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct SelectedUsername: Identifiable {
    let username: String
    var id: String { username }
}

#Preview {
    let fakeDiscourseRepo = FakeDiscourseRepository()
    let fakeKnowledgeRepo = FakeKnowledgeRepository()
    let progressStore = ReadingProgressStore()
    let credentialStore = InMemoryCredentialStore()
    let authRepository = FakeAuthRepository(credentialStore: credentialStore)

    HomeView(
        viewModel: HomeViewModel(
            discourseRepository: fakeDiscourseRepo,
            knowledgeRepository: fakeKnowledgeRepo,
            readingProgressStorage: progressStore,
            authRepository: authRepository
        )
    )
}
