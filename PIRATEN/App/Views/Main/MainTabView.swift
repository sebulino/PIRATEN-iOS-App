//
//  MainTabView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI
import UIKit
import UserNotifications

struct MainTabView: View {
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

    // MARK: - Toolbar Sheet State

    /// Bottom safe area inset inside tab content (includes tab bar + home indicator)
    @State private var tabContentBottomInset: CGFloat = 83

    /// Whether the profile sheet is being shown
    @State private var showingProfile = false

    /// Whether the notifications sheet is being shown
    @State private var showingNotifications = false

    /// Whether the messages sheet is being shown
    @State private var showingMessages = false

    /// Count of delivered notifications currently in the notification center
    @State private var deliveredNotificationsCount: Int = 0

    // MARK: - Compose Flow State

    /// Whether the recipient picker is being shown
    @State private var showingRecipientPicker = false

    /// The selected recipient for composing
    @State private var selectedRecipient: UserSearchResult?

    /// The compose ViewModel (used as item for sheet presentation)
    @State private var composeViewModel: ComposeMessageViewModel?

    /// State for handling deep link navigation to message threads
    @State private var deepLinkedMessageThread: MessageThread?

    /// State for handling deep link navigation to todo detail
    @State private var deepLinkedTodo: Todo?

    /// Whether the notification bell should show a badge
    private var notificationsBadge: Bool {
        deliveredNotificationsCount > 0 || notificationSettings.authorizationStatus == .denied
    }

    var body: some View {
        TabView(selection: $deepLinkRouter.selectedTab) {
            ForumView(
                viewModel: forumViewModel,
                discourseAuthCoordinator: discourseAuthCoordinator,
                topicDetailViewModelFactory: topicDetailViewModelFactory,
                userProfileViewModelFactory: userProfileViewModelFactory,
                onSendMessageFromProfile: { profile in
                    handleSendMessageFromProfile(profile)
                },
                onProfileTapped: { showingProfile = true },
                onNotificationsTapped: { showingNotifications = true },
                notificationsBadge: notificationsBadge,
                onHomeTapped: { deepLinkRouter.selectedTab = 0 },
                onMessagesTapped: { showingMessages = true }
            )
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { tabContentBottomInset = geo.safeAreaInsets.bottom }
                            .onChange(of: geo.safeAreaInsets.bottom) { _, newValue in
                                if newValue > 0 { tabContentBottomInset = newValue }
                            }
                    }
                )
                .tabItem {
                    Label("Forum", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(1)

            NewsView(
                viewModel: newsViewModel,
                onProfileTapped: { showingProfile = true },
                onNotificationsTapped: { showingNotifications = true },
                notificationsBadge: notificationsBadge,
                onHomeTapped: { deepLinkRouter.selectedTab = 0 },
                onMessagesTapped: { showingMessages = true }
            )
                .tabItem {
                    Label("News", systemImage: "newspaper")
                }
                .tag(2)

            KnowledgeView(
                viewModel: knowledgeViewModel,
                topicDetailViewModelFactory: knowledgeTopicDetailViewModelFactory,
                onProfileTapped: { showingProfile = true },
                onNotificationsTapped: { showingNotifications = true },
                notificationsBadge: notificationsBadge,
                onHomeTapped: { deepLinkRouter.selectedTab = 0 },
                onMessagesTapped: { showingMessages = true }
            )
                .tabItem {
                    Label("Wissen", systemImage: "book")
                }
                .tag(3)

            CalendarView(
                viewModel: calendarViewModel,
                onProfileTapped: { showingProfile = true },
                onNotificationsTapped: { showingNotifications = true },
                notificationsBadge: notificationsBadge,
                onHomeTapped: { deepLinkRouter.selectedTab = 0 },
                onMessagesTapped: { showingMessages = true }
            )
                .tabItem {
                    Label("Termine", systemImage: "calendar")
                }
                .tag(4)

            TodosView(
                viewModel: todosViewModel,
                createTodoViewModelFactory: createTodoViewModelFactory,
                todoDetailViewModelFactory: todoDetailViewModelFactory,
                onProfileTapped: { showingProfile = true },
                onNotificationsTapped: { showingNotifications = true },
                notificationsBadge: notificationsBadge,
                onHomeTapped: { deepLinkRouter.selectedTab = 0 },
                onMessagesTapped: { showingMessages = true }
            )
                .tabItem {
                    Label("ToDos", systemImage: "checklist")
                }
                .tag(5)
        }
        .overlay {
            if deepLinkRouter.selectedTab == 0 {
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        HomeView(
                            viewModel: homeViewModel,
                            topicDetailViewModelFactory: topicDetailViewModelFactory,
                            knowledgeTopicDetailViewModelFactory: knowledgeTopicDetailViewModelFactory,
                            userProfileViewModelFactory: userProfileViewModelFactory,
                            onSendMessageFromProfile: { profile in
                                handleSendMessageFromProfile(profile)
                            },
                            onProfileTapped: { showingProfile = true },
                            onNotificationsTapped: { showingNotifications = true },
                            notificationsBadge: notificationsBadge,
                            onMessagesTapped: { showingMessages = true }
                        )
                        .frame(height: geo.size.height - tabContentBottomInset)

                        Color.clear
                            .frame(height: tabContentBottomInset)
                            .allowsHitTesting(false)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showingRecipientPicker, onDismiss: {
            // After recipient picker dismisses, show compose if we have a recipient
            if let recipient = selectedRecipient, let composeFactory = composeMessageViewModelFactory {
                let vm = composeFactory()
                vm.setRecipient(recipient)
                // Small delay to allow sheet dismissal animation to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    composeViewModel = vm
                }
            }
        }) {
            if let factory = recipientPickerViewModelFactory {
                RecipientPickerView(
                    viewModel: factory(),
                    onRecipientSelected: { recipient in
                        selectedRecipient = recipient
                        showingRecipientPicker = false
                        // Compose sheet will be shown in onDismiss
                    },
                    onCancel: {
                        selectedRecipient = nil
                        showingRecipientPicker = false
                    }
                )
            }
        }
        .sheet(item: $composeViewModel, onDismiss: {
            // Clean up when compose sheet is dismissed
            // Check if message was sent before cleaning up
            let wasSent: Bool
            if let vm = composeViewModel, case .sent = vm.state {
                wasSent = true
            } else {
                wasSent = false
            }

            // Clean up state
            selectedRecipient = nil

            // Refresh messages if sent (small delay to allow Discourse to index)
            if wasSent {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    messagesViewModel.refresh()
                }
            }
        }) { vm in
            ComposeMessageView(
                viewModel: vm,
                onChangeRecipient: {
                    // Close compose and reopen recipient picker
                    composeViewModel = nil
                    // Small delay before reopening picker
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingRecipientPicker = true
                    }
                },
                onMessageSent: { _ in
                    composeViewModel = nil
                },
                onCancel: {
                    composeViewModel = nil
                }
            )
        }
        .sheet(item: $deepLinkedMessageThread) { thread in
            // Present message thread detail from deep link
            if let factory = messageThreadDetailViewModelFactory {
                NavigationStack {
                    MessageThreadDetailView(viewModel: factory(thread))
                }
            }
        }
        .sheet(item: $deepLinkedTodo) { todo in
            // Present todo detail from deep link
            if let factory = todoDetailViewModelFactory {
                NavigationStack {
                    TodoDetailView(viewModel: factory(todo))
                }
            }
        }
        .sheet(isPresented: $showingMessages) {
            NavigationStack {
                MessagesView(
                    viewModel: messagesViewModel,
                    messageThreadDetailViewModelFactory: messageThreadDetailViewModelFactory,
                    userProfileViewModelFactory: userProfileViewModelFactory,
                    onSendMessageFromProfile: { profile in
                        handleSendMessageFromProfile(profile)
                    },
                    onComposeTapped: {
                        showingRecipientPicker = true
                    }
                )
            }
        }
        .sheet(isPresented: $showingProfile) {
            NavigationStack {
                ProfileView(
                    viewModel: profileViewModel,
                    notificationSettings: notificationSettings,
                    adminRequestViewModelFactory: adminRequestViewModelFactory,
                    checkAdminStatus: checkAdminStatus
                )
            }
        }
        .sheet(isPresented: $showingNotifications, onDismiss: {
            Task { await refreshDeliveredNotificationsCount() }
        }) {
            NotificationsSheetView()
        }
        .tint(deepLinkRouter.selectedTab == 0 ? Color(.tertiaryLabel) : Color.piratenPrimary)
        .onAppear {
            configureNavigationBarAppearance()
            configureTabBarAppearance()
        }
        .task {
            await refreshDeliveredNotificationsCount()
        }
        .onChange(of: deepLinkRouter.pendingDeepLink) { _, pendingDeepLink in
            guard let deepLink = pendingDeepLink else { return }

            // Handle the deep link based on type
            switch deepLink {
            case .messageThread(let topicId):
                // Open messages sheet and present the deep-linked thread
                showingMessages = true
                Task {
                    messagesViewModel.loadMessages()
                    // Give a moment for messages to load
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    if let thread = messagesViewModel.messageThreads.first(where: { $0.id == topicId }) {
                        deepLinkedMessageThread = thread
                    }
                    // Clear pending deep link after handling
                    deepLinkRouter.clearPendingDeepLink()
                }

            case .todoDetail(let todoId):
                Task {
                    todosViewModel.loadTodos()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if let todoIdInt = Int(todoId),
                       let todo = todosViewModel.todos.first(where: { $0.id == todoIdInt }) {
                        deepLinkedTodo = todo
                    }
                    deepLinkRouter.clearPendingDeepLink()
                }
            }
        }
    }

    // MARK: - Notification Badge Helper

    /// Fetches the count of delivered notifications to update the bell badge.
    @MainActor
    private func refreshDeliveredNotificationsCount() async {
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        deliveredNotificationsCount = delivered.count
    }

    // MARK: - Appearance Configuration

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Color.piratenPrimary)
        ]
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(Color.piratenPrimary)
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(Color.piratenPrimary)
    }

    private func configureTabBarAppearance() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    // MARK: - Profile Messaging Helper

    /// Handles "Nachricht senden" from user profile view.
    /// Creates a UserSearchResult from the profile and pre-fills the compose flow.
    private func handleSendMessageFromProfile(_ profile: UserProfile) {
        // Convert UserProfile to UserSearchResult for compose flow
        let recipient = UserSearchResult(
            username: profile.username,
            displayName: profile.displayName,
            avatarUrl: profile.avatarUrl
        )
        selectedRecipient = recipient

        // Create and show compose view with pre-filled recipient
        if let composeFactory = composeMessageViewModelFactory {
            let vm = composeFactory()
            vm.setRecipient(recipient)
            composeViewModel = vm
        }
    }
}

#Preview {
    // Preview with fake data - all ViewModels use fake repositories
    // Note: Profile requires authenticated session for user data
    let credentialStore = InMemoryCredentialStore()
    let authRepository = FakeAuthRepository(credentialStore: credentialStore)
    let fakeDiscourseRepo = FakeDiscourseRepository()
    let discourseAPIKeyProvider = KeychainDiscourseAPIKeyProvider(credentialStore: credentialStore)
    let recentRecipientsStore = RecentRecipientsStore()
    let deviceTokenManager = DeviceTokenManager()

    let fakeKnowledgeRepo = FakeKnowledgeRepository()
    let progressStore = ReadingProgressStore()

    MainTabView(
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
        userProfileViewModelFactory: { username in
            UserProfileViewModel(username: username, discourseRepository: fakeDiscourseRepo)
        },
        createTodoViewModelFactory: {
            CreateTodoViewModel(todoRepository: FakeTodoRepository())
        },
        todoDetailViewModelFactory: { todo in
            TodoDetailViewModel(todo: todo, todoRepository: FakeTodoRepository())
        },
        adminRequestViewModelFactory: {
            AdminRequestViewModel(todoRepository: FakeTodoRepository())
        }
    )
}
