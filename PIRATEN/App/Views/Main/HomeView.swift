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

    /// Callback when user taps the profile toolbar button
    var onProfileTapped: (() -> Void)?

    /// Callback when user taps the notifications toolbar button
    var onNotificationsTapped: (() -> Void)?

    /// Whether to show a badge on the notification bell
    var notificationsBadge: Bool = false

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
            .navigationTitle("Kajüte")
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
                    viewModel.loadDashboard()
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
                            contactAvatar(contact)
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
                    if let factory = topicDetailViewModelFactory {
                        NavigationLink {
                            TopicDetailView(viewModel: factory(topic))
                        } label: {
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
