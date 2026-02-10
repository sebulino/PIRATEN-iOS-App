//
//  MainTabView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject var forumViewModel: ForumViewModel
    @ObservedObject var messagesViewModel: MessagesViewModel
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

    /// Factory for creating TodoDetailViewModels
    var todoDetailViewModelFactory: ((Todo) -> TodoDetailViewModel)?

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

    var body: some View {
        TabView(selection: $deepLinkRouter.selectedTab) {
            ForumView(
                viewModel: forumViewModel,
                discourseAuthCoordinator: discourseAuthCoordinator,
                topicDetailViewModelFactory: topicDetailViewModelFactory,
                userProfileViewModelFactory: userProfileViewModelFactory,
                onSendMessageFromProfile: { profile in
                    handleSendMessageFromProfile(profile)
                }
            )
                .tabItem {
                    Label("Forum", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(0)

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
                .tabItem {
                    Label("Nachrichten", systemImage: "envelope")
                }
                .tag(1)

            KnowledgeView()
                .tabItem {
                    Label("Wissen", systemImage: "book")
                }
                .tag(2)

            TodosView(
                viewModel: todosViewModel,
                createTodoViewModelFactory: createTodoViewModelFactory,
                todoDetailViewModelFactory: todoDetailViewModelFactory
            )
                .tabItem {
                    Label("ToDos", systemImage: "checklist")
                }
                .tag(3)

            ProfileView(viewModel: profileViewModel, notificationSettings: notificationSettings)
                .tabItem {
                    Label("Profil", systemImage: "person.circle")
                }
                .tag(4)
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
        .onChange(of: deepLinkRouter.pendingDeepLink) { _, pendingDeepLink in
            guard let deepLink = pendingDeepLink else { return }

            // Handle the deep link based on type
            switch deepLink {
            case .messageThread(let topicId):
                // Fetch thread data and present detail view
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

    MainTabView(
        forumViewModel: ForumViewModel(discourseRepository: fakeDiscourseRepo),
        messagesViewModel: MessagesViewModel(
            discourseRepository: fakeDiscourseRepo,
            authRepository: authRepository
        ),
        todosViewModel: TodosViewModel(todoRepository: FakeTodoRepository()),
        profileViewModel: ProfileViewModel(authRepository: authRepository),
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
        }
    )
}
