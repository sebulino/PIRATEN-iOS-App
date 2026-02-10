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

    // MARK: - Splash Screen State

    /// Whether to show the startup splash screen
    @State private var showSplash = true

    // MARK: - Body

    var body: some View {
        ZStack {
            // Main app content (always rendered underneath)
            RootView(
                authStateManager: authStateManager,
                forumViewModel: forumViewModel,
                messagesViewModel: messagesViewModel,
                todosViewModel: todosViewModel,
                profileViewModel: profileViewModel,
                discourseAuthCoordinator: discourseAuthCoordinator,
                notificationSettings: notificationSettings,
                deepLinkRouter: deepLinkRouter,
                topicDetailViewModelFactory: topicDetailViewModelFactory,
                messageThreadDetailViewModelFactory: messageThreadDetailViewModelFactory,
                recipientPickerViewModelFactory: recipientPickerViewModelFactory,
                composeMessageViewModelFactory: composeMessageViewModelFactory,
                userProfileViewModelFactory: userProfileViewModelFactory
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

            withAnimation(.easeOut(duration: 0.5)) {
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

    StartupContainerView(
        authStateManager: AuthStateManager(authRepository: authRepository),
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
        }
    )
}
