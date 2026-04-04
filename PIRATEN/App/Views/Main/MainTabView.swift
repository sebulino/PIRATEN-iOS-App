//
//  MainTabView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI
import UIKit
import UserNotifications
import Combine

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

    // MARK: - Toolbar Sheet State

    /// Whether the profile sheet is being shown
    @State private var showingProfile = false

    /// Whether the notifications sheet is being shown
    @State private var showingNotifications = false

    /// Whether the messages sheet is being shown
    @State private var showingMessages = false

    /// Whether the news sheet is being shown
    @State private var showingNews = false

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

    /// Scene phase for foreground/background polling control
    @Environment(\.scenePhase) private var scenePhase

    /// Timer for foreground notification polling
    @State private var pollingTimer: Timer?

    /// Whether any content across all categories is unread
    private var anyContentUnread: Bool {
        messagesViewModel.hasNewContent ||
        forumViewModel.hasNewContent ||
        todosViewModel.hasNewContent ||
        newsViewModel.hasNewContent ||
        calendarViewModel.hasNewContent
    }

    /// Whether the notification bell should show a badge
    private var notificationsBadge: Bool {
        deliveredNotificationsCount > 0 || notificationSettings.authorizationStatus == .denied
    }

    var body: some View {
        TabView(selection: $deepLinkRouter.selectedTab) {
            HomeView(
                viewModel: homeViewModel,
                topicDetailViewModelFactory: topicDetailViewModelFactory,
                knowledgeTopicDetailViewModelFactory: knowledgeTopicDetailViewModelFactory,
                todoDetailViewModelFactory: todoDetailViewModelFactory,
                userProfileViewModelFactory: userProfileViewModelFactory,
                onSendMessageFromProfile: { profile in
                    handleSendMessageFromProfile(profile)
                },
                onProfileTapped: { showingProfile = true },
                onNotificationsTapped: { showingNotifications = true },
                notificationsBadge: notificationsBadge,
                onMessagesTapped: { showingMessages = true },
                messagesBadge: messagesViewModel.hasNewContent,
                onNewsTapped: { showingNews = true },
                newsBadge: newsViewModel.hasNewContent,
                feedbackViewModelFactory: feedbackViewModelFactory
            )
                .tabItem {
                    Label {
                        Text("Kajüte")
                    } icon: {
                        Image("kajuete")
                            .renderingMode(.template)
                    }
                }
                .tag(0)

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
                onMessagesTapped: { showingMessages = true },
                messagesBadge: messagesViewModel.hasNewContent,
                onNewsTapped: { showingNews = true },
                newsBadge: newsViewModel.hasNewContent
            )
                .tabItem {
                    Label {
                        Text("Forum")
                    } icon: {
                        Image("forum")
                            .renderingMode(.template)
                    }
                }
                .tag(1)
                .badge(forumViewModel.hasNewContent ? Text(" ") : nil)

            KnowledgeView(
                viewModel: knowledgeViewModel,
                topicDetailViewModelFactory: knowledgeTopicDetailViewModelFactory,
                onProfileTapped: { showingProfile = true },
                onNotificationsTapped: { showingNotifications = true },
                notificationsBadge: notificationsBadge,
                onMessagesTapped: { showingMessages = true },
                messagesBadge: messagesViewModel.hasNewContent,
                onNewsTapped: { showingNews = true },
                newsBadge: newsViewModel.hasNewContent
            )
                .tabItem {
                    Label {
                        Text("Wissen")
                    } icon: {
                        Image("wissen")
                            .renderingMode(.template)
                    }
                }
                .tag(3)
                .badge(Text?.none)

            CalendarView(
                viewModel: calendarViewModel,
                onProfileTapped: { showingProfile = true },
                onNotificationsTapped: { showingNotifications = true },
                notificationsBadge: notificationsBadge,
                onMessagesTapped: { showingMessages = true },
                messagesBadge: messagesViewModel.hasNewContent,
                onNewsTapped: { showingNews = true },
                newsBadge: newsViewModel.hasNewContent
            )
                .tabItem {
                    Label {
                        Text("Termine")
                    } icon: {
                        Image("termine")
                            .renderingMode(.template)
                    }
                }
                .tag(4)
                .badge(calendarViewModel.hasNewContent ? Text(" ") : nil)

            TodosView(
                viewModel: todosViewModel,
                createTodoViewModelFactory: createTodoViewModelFactory,
                todoDetailViewModelFactory: todoDetailViewModelFactory,
                onProfileTapped: { showingProfile = true },
                onNotificationsTapped: { showingNotifications = true },
                notificationsBadge: notificationsBadge,
                onMessagesTapped: { showingMessages = true },
                messagesBadge: messagesViewModel.hasNewContent,
                onNewsTapped: { showingNews = true },
                newsBadge: newsViewModel.hasNewContent
            )
                .tabItem {
                    Label {
                        Text("ToDos")
                    } icon: {
                        Image("todos")
                            .renderingMode(.template)
                    }
                }
                .tag(5)
                .badge(todosViewModel.hasNewContent ? Text(" ") : nil)
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
                    MessageThreadDetailView(
                        viewModel: factory(thread),
                        discourseAuthCoordinator: discourseAuthCoordinator
                    )
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
        .sheet(isPresented: $showingNews, onDismiss: {
            newsViewModel.markAsViewed()
        }) {
            NewsView(viewModel: newsViewModel)
        }
        .sheet(isPresented: $showingMessages, onDismiss: {
            // Sync unread count back to home dashboard after reading messages
            homeViewModel.updateUnreadMessageCount(
                messagesViewModel.messageThreads.filter { !$0.isRead }.count
            )
        }) {
            NavigationStack {
                MessagesView(
                    viewModel: messagesViewModel,
                    discourseAuthCoordinator: discourseAuthCoordinator,
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
                    checkAdminStatus: checkAdminStatus,
                    onLogout: onLogout
                )
            }
        }
        .sheet(isPresented: $showingNotifications, onDismiss: {
            Task { await refreshDeliveredNotificationsCount() }
        }) {
            NotificationsSheetView()
        }
        .tint(Color.piratenPrimary)
        .onChange(of: deepLinkRouter.selectedTab) { _, newTab in
            switch newTab {
            case 1:
                forumViewModel.markAsViewed()
                if forumViewModel.loadState == .loaded {
                    forumViewModel.refresh()
                }
            case 3: knowledgeViewModel.markAsViewed()
            case 4: calendarViewModel.markAsViewed()
            case 5: todosViewModel.markAsViewed()
            default: break
            }
        }
        .onAppear {
            configureNavigationBarAppearance()
            configureTabBarAppearance()
            // Load data at startup so badges reflect unread state immediately
            if messagesViewModel.loadState == .idle {
                messagesViewModel.loadMessages()
            }
            if forumViewModel.loadState == .idle {
                forumViewModel.loadTopics()
            }
            if todosViewModel.loadState == .idle {
                todosViewModel.loadTodos()
            }
            if newsViewModel.loadState == .idle {
                newsViewModel.loadNews()
            }
            // Start foreground polling if notifications are enabled
            startPollingIfNeeded()
        }
        .onDisappear {
            stopPolling()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // Poll immediately on foreground return, then resume timer
                if notificationSettings.anyNotificationsEnabled {
                    Task { await notificationPoller.poll() }
                    startPollingIfNeeded()
                }
                Task { await refreshDeliveredNotificationsCount() }
            case .background, .inactive:
                stopPolling()
            @unknown default:
                break
            }
        }
        .onChange(of: notificationSettings.anyNotificationsEnabled) { _, enabled in
            if enabled {
                startPollingIfNeeded()
            } else {
                stopPolling()
            }
        }
        .onChange(of: messagesViewModel.hasNewContent) { old, new in
            if new && !old && notificationSettings.messagesEnabled {
                scheduleLocalNotification(
                    title: "Neue Nachrichten",
                    body: "Du hast neue private Nachrichten.",
                    category: "messages"
                )
            }
        }
        .onChange(of: forumViewModel.hasNewContent) { old, new in
            if new && !old && notificationSettings.forumEnabled {
                scheduleLocalNotification(
                    title: "Neuer Forumsbeitrag",
                    body: "Es gibt neue Beiträge im Forum.",
                    category: "forum"
                )
            }
        }
        .onChange(of: todosViewModel.hasNewContent) { old, new in
            if new && !old && notificationSettings.todosEnabled {
                scheduleLocalNotification(
                    title: "Neue Aufgaben",
                    body: "Es gibt neue oder geänderte Aufgaben.",
                    category: "todos"
                )
            }
        }
        .onChange(of: newsViewModel.hasNewContent) { old, new in
            if new && !old && notificationSettings.newsEnabled {
                scheduleLocalNotification(
                    title: "Neue Neuigkeiten",
                    body: "Es gibt neue Neuigkeiten.",
                    category: "news"
                )
            }
        }
        .onChange(of: anyContentUnread) { _, hasUnread in
            if !hasUnread {
                Task { try? await UNUserNotificationCenter.current().setBadgeCount(0) }
            }
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

            case .forumTopic:
                // DeepLinkRouter already switched to Forum tab (tag 1).
                // The Forum tab will show the topic list; navigation to a specific
                // topic within the tab is not yet implemented (see OPEN_QUESTIONS.md Q-014).
                deepLinkRouter.clearPendingDeepLink()
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

    // MARK: - Notification Polling

    /// Starts the foreground polling timer (every 60 seconds) if any notifications are enabled.
    private func startPollingIfNeeded() {
        guard notificationSettings.anyNotificationsEnabled else { return }
        guard pollingTimer == nil else { return }

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                await notificationPoller.poll()
                await refreshDeliveredNotificationsCount()
            }
        }
    }

    /// Stops the foreground polling timer.
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    /// Schedules a local notification for a specific content category.
    private func scheduleLocalNotification(title: String, body: String, category: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(category)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        Task {
            try? await UNUserNotificationCenter.current().add(request)
            await refreshDeliveredNotificationsCount()
        }
    }

    // MARK: - Appearance Configuration

    private func configureNavigationBarAppearance() {
        // Font + color are configured centrally in PiratenAppearance.configure().
        // Only set tint color here (for back button and bar button items).
        UINavigationBar.appearance().tintColor = UIColor(Color.piratenPrimary)
    }

    private func configureTabBarAppearance() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Orange badge dot for new content indicators
        UITabBarItem.appearance().badgeColor = UIColor(Color.piratenPrimary)
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

    let fakeKnowledgeRepo = FakeKnowledgeRepository()
    let progressStore = ReadingProgressStore()
    let notificationSettingsManager = NotificationSettingsManager()

    MainTabView(
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
