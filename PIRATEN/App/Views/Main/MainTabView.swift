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

    /// Factory for creating TopicDetailViewModels
    var topicDetailViewModelFactory: ((Topic) -> TopicDetailViewModel)?

    /// Factory for creating MessageThreadDetailViewModels
    var messageThreadDetailViewModelFactory: ((MessageThread) -> MessageThreadDetailViewModel)?

    /// Factory for creating RecipientPickerViewModels
    var recipientPickerViewModelFactory: (() -> RecipientPickerViewModel)?

    /// Factory for creating ComposeMessageViewModels
    var composeMessageViewModelFactory: (() -> ComposeMessageViewModel)?

    // MARK: - Compose Flow State

    /// Whether the recipient picker is being shown
    @State private var showingRecipientPicker = false

    /// The selected recipient for composing
    @State private var selectedRecipient: UserSearchResult?

    /// The compose ViewModel (used as item for sheet presentation)
    @State private var composeViewModel: ComposeMessageViewModel?

    var body: some View {
        TabView {
            ForumView(
                viewModel: forumViewModel,
                discourseAuthCoordinator: discourseAuthCoordinator,
                topicDetailViewModelFactory: topicDetailViewModelFactory
            )
                .tabItem {
                    Label("Forum", systemImage: "bubble.left.and.bubble.right")
                }

            MessagesView(
                viewModel: messagesViewModel,
                messageThreadDetailViewModelFactory: messageThreadDetailViewModelFactory,
                onComposeTapped: {
                    showingRecipientPicker = true
                }
            )
                .tabItem {
                    Label("Nachrichten", systemImage: "envelope")
                }

            KnowledgeView()
                .tabItem {
                    Label("Knowledge", systemImage: "book")
                }

            TodosView(viewModel: todosViewModel)
                .tabItem {
                    Label("Todos", systemImage: "checklist")
                }

            ProfileView(viewModel: profileViewModel, notificationSettings: notificationSettings)
                .tabItem {
                    Label("Profil", systemImage: "person.circle")
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

    return MainTabView(
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
        notificationSettings: NotificationSettingsManager(),
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
