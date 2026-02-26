//
//  StartupContainerView.swift
//  PIRATEN
//
//  Created by Claude Code on 09.02.26.
//

import SwiftUI

/// Container view that coordinates the startup screen with the main app content.
/// Shows the startup screen on app launch, then transitions to RootView after
/// authentication check completes and a minimum branding display time has elapsed.
///
/// Privacy note: No user data or timing metrics are collected or logged.
struct StartupContainerView: View {
    // MARK: - View Model Dependencies (passed through to RootView)

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

    /// Factory for creating AdminRequestViewModels
    var adminRequestViewModelFactory: (() -> AdminRequestViewModel)?

    /// Closure to check the current user's admin status
    var checkAdminStatus: (() async -> Bool?)?

    // MARK: - Splash Screen State

    /// Whether to show the startup splash screen
    @State private var showSplash = true

    // MARK: - Body

    var body: some View {
        ZStack {
            // Main app content (always rendered underneath)
            RootView(
                authStateManager: authStateManager,
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
                deepLinkRouter: deepLinkRouter,
                topicDetailViewModelFactory: topicDetailViewModelFactory,
                messageThreadDetailViewModelFactory: messageThreadDetailViewModelFactory,
                recipientPickerViewModelFactory: recipientPickerViewModelFactory,
                composeMessageViewModelFactory: composeMessageViewModelFactory,
                userProfileViewModelFactory: userProfileViewModelFactory,
                createTodoViewModelFactory: createTodoViewModelFactory,
                knowledgeTopicDetailViewModelFactory: knowledgeTopicDetailViewModelFactory,
                todoDetailViewModelFactory: todoDetailViewModelFactory,
                adminRequestViewModelFactory: adminRequestViewModelFactory,
                checkAdminStatus: checkAdminStatus
            )

            // Startup splash screen overlay (dismisses after delay)
            if showSplash {
                StartupScreenView()
                    .transition(.opacity)
                    .zIndex(999) // Ensure it's on top
            }
        }
        .task {
            // Fixed branding display time - avoids polling authStateManager
            // which causes AttributeGraph cycles with RootView's own .task
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

            withAnimation(.easeOut(duration: 0.25)) {
                showSplash = false
            }
        }
    }
}

#Preview {
    let credentialStore = InMemoryCredentialStore()
    let authRepository = FakeAuthRepository(credentialStore: credentialStore)
    let fakeDiscourseRepo = FakeDiscourseRepository()
    let discourseAPIKeyProvider = KeychainDiscourseAPIKeyProvider(credentialStore: credentialStore)
    let recentRecipientsStore = RecentRecipientsStore()
    let deviceTokenManager = DeviceTokenManager()

    let fakeKnowledgeRepo = FakeKnowledgeRepository()
    let progressStore = ReadingProgressStore()

    StartupContainerView(
        authStateManager: AuthStateManager(authRepository: authRepository),
        homeViewModel: HomeViewModel(
            discourseRepository: fakeDiscourseRepo,
            knowledgeRepository: fakeKnowledgeRepo,
            readingProgressStorage: progressStore,
            authRepository: authRepository
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
        notificationSettings: NotificationSettingsManager(deviceTokenManager: deviceTokenManager),
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
