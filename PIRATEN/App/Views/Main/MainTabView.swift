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
        .sheet(isPresented: $showingRecipientPicker) {
            if let factory = recipientPickerViewModelFactory {
                RecipientPickerView(
                    viewModel: factory(),
                    onRecipientSelected: { recipient in
                        selectedRecipient = recipient
                        showingRecipientPicker = false
                        // Create compose ViewModel and show compose sheet
                        if let composeFactory = composeMessageViewModelFactory {
                            let vm = composeFactory()
                            vm.setRecipient(recipient)
                            composeViewModel = vm
                            showingCompose = true
                        }
                    },
                    onCancel: {
                        showingRecipientPicker = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingCompose) {
            if let vm = composeViewModel {
                ComposeMessageView(
                    viewModel: vm,
                    onChangeRecipient: {
                        // Close compose and reopen recipient picker
                        showingCompose = false
                        showingRecipientPicker = true
                    },
                    onMessageSent: { _ in
                        showingCompose = false
                        composeViewModel = nil
                        // Refresh messages list to show new thread
                        messagesViewModel.refresh()
                    },
                    onCancel: {
                        showingCompose = false
                        composeViewModel = nil
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
