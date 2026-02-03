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

    /// Whether the compose view is being shown
    @State private var showingCompose = false

    /// The selected recipient for composing
    @State private var selectedRecipient: UserSearchResult?

    /// The compose ViewModel (created when compose sheet is shown)
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

            ProfileView(viewModel: profileViewModel)
                .tabItem {
                    Label("Profil", systemImage: "person.circle")
                }
        }
        .sheet(isPresented: $showingRecipientPicker, onDismiss: {
            // After recipient picker dismisses, show compose if we have a recipient
            if selectedRecipient != nil, let composeFactory = composeMessageViewModelFactory {
                let vm = composeFactory()
                if let recipient = selectedRecipient {
                    vm.setRecipient(recipient)
                }
                composeViewModel = vm
                // Small delay to allow sheet dismissal animation to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingCompose = true
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
        .sheet(isPresented: $showingCompose, onDismiss: {
            // Clean up when compose sheet is dismissed
            // Check if message was sent before cleaning up
            let wasSent: Bool
            if let vm = composeViewModel, case .sent = vm.state {
                wasSent = true
            } else {
                wasSent = false
            }

            // Clean up state
            composeViewModel = nil
            selectedRecipient = nil

            // Refresh messages if sent (small delay to allow Discourse to index)
            if wasSent {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    messagesViewModel.refresh()
                }
            }
        }) {
            if let vm = composeViewModel {
                ComposeMessageView(
                    viewModel: vm,
                    onChangeRecipient: {
                        // Close compose and reopen recipient picker
                        showingCompose = false
                        // Small delay before reopening picker
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingRecipientPicker = true
                        }
                    },
                    onMessageSent: { _ in
                        showingCompose = false
                    },
                    onCancel: {
                        showingCompose = false
                    }
                )
            }
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
