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

    /// Factory for creating TodoDetailViewModels
    var todoDetailViewModelFactory: ((Todo) -> TodoDetailViewModel)?

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

    /// Whether to show a badge on the messages toolbar button
    var messagesBadge: Bool = false

    /// Callback when user taps the news toolbar button
    var onNewsTapped: (() -> Void)?

    /// Whether to show a badge on the news toolbar button
    var newsBadge: Bool = false

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
                    HStack(spacing: 2) {
                        PiratenIconButton(
                            imageName: "nachrichten",
                            badge: messagesBadge,
                            accessibilityLabel: "Nachrichten"
                        ) {
                            onMessagesTapped?()
                        }
                        PiratenIconButton(
                            imageName: "neuigkeiten",
                            badge: newsBadge,
                            accessibilityLabel: "News"
                        ) {
                            onNewsTapped?()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 2) {
//                        PiratenIconButton(
//                            imageName: "benachrichtigungen",
//                            badge: notificationsBadge,
//                            accessibilityLabel: "Benachrichtigungen"
//                        ) {
//                            onNotificationsTapped?()
//                        }

                        PiratenIconButton(
                            imageName: "profil",
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
                // Greeting
                if let firstName = viewModel.userFirstName {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ahoi \(firstName)!")
                            .font(.piratenTitle2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)

                        if viewModel.unreadMessageCount == 0 {
                            Text("Du hast keine neuen Nachrichten.")
                                .font(.piratenSubheadline)
                                .foregroundColor(.secondary)
                        } else if viewModel.unreadMessageCount == 1 {
                            Text("Du hast eine neue Nachricht.")
                                .font(.piratenSubheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Du hast \(viewModel.unreadMessageCount) neue Nachrichten.")
                                .font(.piratenSubheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Section 1: Recent Contacts
                recentContactsSection

                // Section 2: Knowledge Articles
                knowledgeSection

                // Section 3: Claimed Todos
                claimedTodosSection

                // Section 4: Recent Forum Topics
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
                .font(.piratenTitle3)
                .fontWeight(.bold)
                .foregroundColor(.orange)

            if viewModel.recentContacts.isEmpty {
                Text("Noch keine Nachrichten")
                    .font(.piratenSubheadline)
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
                .font(.piratenCaption)
                .lineLimit(1)
                .frame(width: 56)
        }
    }

    // MARK: - Section 2: Knowledge Articles

    @ViewBuilder
    private var knowledgeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weiterlesen")
                .font(.piratenTitle3)
                .fontWeight(.bold)
                .foregroundColor(.orange)

            if viewModel.knowledgeArticles.isEmpty {
                Text("Entdecke den Wissensbereich")
                    .font(.piratenSubheadline)
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
                    .font(.piratenCallout)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Text(topic.summary)
                    .font(.piratenCaption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.piratenCaption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Section 3: Claimed Todos

    @ViewBuilder
    private var claimedTodosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Übernommene Aufgaben")
                .font(.piratenTitle3)
                .fontWeight(.bold)
                .foregroundColor(.orange)

            if viewModel.claimedTodos.isEmpty {
                Text("Du hast aktuell keine übernommenen ToDos.")
                    .font(.piratenSubheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.claimedTodos) { todo in
                    if let factory = todoDetailViewModelFactory {
                        NavigationLink {
                            TodoDetailView(viewModel: factory(todo))
                        } label: {
                            TodoRow(
                                todo: todo,
                                categoryName: viewModel.categoryName(for: todo),
                                entityName: viewModel.entityName(for: todo),
                                hideStatus: true
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        TodoRow(
                            todo: todo,
                            categoryName: viewModel.categoryName(for: todo),
                            entityName: viewModel.entityName(for: todo),
                            hideStatus: true
                        )
                    }
                    if todo.id != viewModel.claimedTodos.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Section 4: Recent Forum Topics

    @ViewBuilder
    private var recentTopicsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aktuelle Themen")
                .font(.piratenTitle3)
                .fontWeight(.bold)
                .foregroundColor(.orange)

            if viewModel.recentTopics.isEmpty {
                Text("Keine Themen verfügbar")
                    .font(.piratenSubheadline)
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
            Text(HTMLContentParser.replaceEmojiShortcodes(in: topic.title))
                .font(.piratenSubheadline)
                .fontWeight(.medium)
                .lineLimit(2)

            HStack(spacing: 12) {
                Label("\(max(0, topic.postsCount - 1))", systemImage: "bubble.right")
                    .font(.piratenCaption)
                    .foregroundColor(.secondary)

                Text(topic.createdAt, style: .relative)
                    .font(.piratenCaption)
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
            authRepository: authRepository,
            todoRepository: FakeTodoRepository()
        )
    )
}
