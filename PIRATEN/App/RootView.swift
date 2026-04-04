//
//  RootView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct RootView: View {
    @ObservedObject var authStateManager: AuthStateManager
    @ObservedObject var homeViewModel: HomeViewModel
    @ObservedObject var forumViewModel: ForumViewModel
    @ObservedObject var newsViewModel: NewsViewModel
    @ObservedObject var messagesViewModel: MessagesViewModel
    @ObservedObject var knowledgeViewModel: KnowledgeViewModel
    @ObservedObject var calendarViewModel: CalendarViewModel
    @ObservedObject var todosViewModel: TodosViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @ObservedObject var discourseAuthCoordinator: DiscourseAuthCoordinator
    @ObservedObject var notificationSettings: NotificationSettingsManager
    @ObservedObject var notificationPoller: DiscourseNotificationPoller
    @ObservedObject var deepLinkRouter: DeepLinkRouter

    /// Factory for creating TopicDetailViewModels
    var topicDetailViewModelFactory: ((Topic) -> TopicDetailViewModel)?

    /// Factory for creating MessageThreadDetailViewModels
    var messageThreadDetailViewModelFactory: ((MessageThread) -> MessageThreadDetailViewModel)?

    /// Factory for creating RecipientPickerViewModels
    var recipientPickerViewModelFactory: (() -> RecipientPickerViewModel)?

    /// Factory for creating ComposeMessageViewModels
    var composeMessageViewModelFactory: (() -> ComposeMessageViewModel)?

    /// Factory for creating UserProfileViewModels
    var userProfileViewModelFactory: ((String) -> UserProfileViewModel)?

    /// Factory for creating CreateTodoViewModels
    var createTodoViewModelFactory: (() -> CreateTodoViewModel)?

    /// Factory for creating KnowledgeTopicDetailViewModels
    var knowledgeTopicDetailViewModelFactory: ((KnowledgeTopic) -> KnowledgeTopicDetailViewModel)?

    /// Factory for creating TodoDetailViewModels
    var todoDetailViewModelFactory: ((Todo) -> TodoDetailViewModel)?

    /// Factory for creating FeedbackViewModels
    var feedbackViewModelFactory: ((FeedbackType) -> FeedbackViewModel)?

    /// Factory for creating AdminRequestViewModels
    var adminRequestViewModelFactory: (() -> AdminRequestViewModel)?

    /// Closure to check the current user's admin status
    var checkAdminStatus: (() async -> Bool?)?

    /// Callback when user taps the logout button
    var onLogout: (() -> Void)?

    var body: some View {
        Group {
            switch authStateManager.currentState {
            case .unauthenticated, .authenticating:
                LoginView(authStateManager: authStateManager)
                    .onChange(of: authStateManager.currentState) { _, newState in
                        // If user just authenticated and there's a pending deep link,
                        // it will be handled by MainTabView when it appears
                    }
            case .authenticated:
                MainTabView(
                    homeViewModel: homeViewModel,
                    forumViewModel: forumViewModel,
                    newsViewModel: newsViewModel,
                    messagesViewModel: messagesViewModel,
                    knowledgeViewModel: knowledgeViewModel,
                    calendarViewModel: calendarViewModel,
                    todosViewModel: todosViewModel,
                    profileViewModel: profileViewModel,
                    discourseAuthCoordinator: discourseAuthCoordinator,
                    notificationSettings: notificationSettings,
                    notificationPoller: notificationPoller,
                    deepLinkRouter: deepLinkRouter,
                    topicDetailViewModelFactory: topicDetailViewModelFactory,
                    messageThreadDetailViewModelFactory: messageThreadDetailViewModelFactory,
                    recipientPickerViewModelFactory: recipientPickerViewModelFactory,
                    composeMessageViewModelFactory: composeMessageViewModelFactory,
                    userProfileViewModelFactory: userProfileViewModelFactory,
                    createTodoViewModelFactory: createTodoViewModelFactory,
                    knowledgeTopicDetailViewModelFactory: knowledgeTopicDetailViewModelFactory,
                    todoDetailViewModelFactory: todoDetailViewModelFactory,
                    feedbackViewModelFactory: feedbackViewModelFactory,
                    adminRequestViewModelFactory: adminRequestViewModelFactory,
                    checkAdminStatus: checkAdminStatus,
                    onLogout: onLogout
                )
                .provideWindow()
            case .failed(let error):
                ErrorView(error: error, authStateManager: authStateManager)
            case .sessionExpired:
                SessionExpiredView(authStateManager: authStateManager)
            }
        }
        .task {
            // Check for existing valid session on app launch
            // This restores authentication state if tokens are present in Keychain
            authStateManager.checkExistingSession()
        }
    }
}

struct ErrorView: View {
    let error: AuthError
    @ObservedObject var authStateManager: AuthStateManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Fehler")
                .font(.piratenTitle)
                .fontWeight(.bold)

            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .padding()

            Button("Zurück") {
                authStateManager.logout()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

/// View shown when the user's session has expired (401/403 from server).
/// Provides a clear message and button to re-authenticate.
/// This is part of M3B-006: Auth error handling across API clients.
struct SessionExpiredView: View {
    @ObservedObject var authStateManager: AuthStateManager

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundColor(.piratenPrimary)

            Text("Sitzung abgelaufen")
                .font(.piratenTitle)
                .fontWeight(.bold)

            Text("Deine Sitzung ist abgelaufen. Bitte melde dich erneut an, um fortzufahren.")
                .font(.piratenBodyDefault)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                authStateManager.authenticate()
            } label: {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Erneut anmelden")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

#Preview {
    let credentialStore = InMemoryCredentialStore()
    let authRepository = FakeAuthRepository(credentialStore: credentialStore)
    let fakeDiscourseRepo = FakeDiscourseRepository()
    let discourseAPIKeyProvider = KeychainDiscourseAPIKeyProvider(credentialStore: credentialStore)
    let recentRecipientsStore = RecentRecipientsStore()

    let fakeKnowledgeRepo = FakeKnowledgeRepository()
    let progressStore = ReadingProgressStore()
    let notificationSettingsManager = NotificationSettingsManager()

    RootView(
        authStateManager: AuthStateManager(authRepository: authRepository),
        homeViewModel: HomeViewModel(
            discourseRepository: fakeDiscourseRepo,
            knowledgeRepository: fakeKnowledgeRepo,
            readingProgressStorage: progressStore,
            authRepository: authRepository,
            todoRepository: FakeTodoRepository()
        ),
        forumViewModel: ForumViewModel(discourseRepository: fakeDiscourseRepo),
        newsViewModel: NewsViewModel(newsRepository: FakeNewsRepository(), cache: NewsCacheStore()),
        messagesViewModel: MessagesViewModel(
            discourseRepository: fakeDiscourseRepo,
            authRepository: authRepository
        ),
        knowledgeViewModel: KnowledgeViewModel(
            repository: fakeKnowledgeRepo,
            progressStore: progressStore
        ),
        calendarViewModel: CalendarViewModel(calendarRepository: FakeCalendarRepository()),
        todosViewModel: TodosViewModel(todoRepository: FakeTodoRepository()),
        profileViewModel: ProfileViewModel(authRepository: authRepository, discourseRepository: fakeDiscourseRepo),
        discourseAuthCoordinator: DiscourseAuthCoordinator(
            discourseAuthManager: nil,
            discourseAPIKeyProvider: discourseAPIKeyProvider,
            credentialStore: credentialStore
        ),
        notificationSettings: notificationSettingsManager,
        notificationPoller: DiscourseNotificationPoller(
            httpClient: URLSessionHTTPClient.withCaching(),
            baseURL: URL(string: "https://diskussion.piratenpartei.de")!,
            notificationSettingsManager: notificationSettingsManager
        ),
        deepLinkRouter: DeepLinkRouter(),
        topicDetailViewModelFactory: { topic in
            TopicDetailViewModel(topic: topic, discourseRepository: fakeDiscourseRepo)
        },
        messageThreadDetailViewModelFactory: { thread in
            MessageThreadDetailViewModel(thread: thread, discourseRepository: fakeDiscourseRepo)
        },
        recipientPickerViewModelFactory: {
            RecipientPickerViewModel(
                discourseRepository: fakeDiscourseRepo,
                recentRecipientsStorage: recentRecipientsStore
            )
        },
        composeMessageViewModelFactory: {
            ComposeMessageViewModel(
                discourseRepository: fakeDiscourseRepo,
                recentRecipientsStorage: recentRecipientsStore
            )
        },
        createTodoViewModelFactory: {
            CreateTodoViewModel(todoRepository: FakeTodoRepository())
        },
        todoDetailViewModelFactory: { todo in
            TodoDetailViewModel(todo: todo, todoRepository: FakeTodoRepository())
        }
    )
}
