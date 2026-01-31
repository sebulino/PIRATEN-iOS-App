//
//  RootView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct RootView: View {
    @ObservedObject var authStateManager: AuthStateManager
    @ObservedObject var forumViewModel: ForumViewModel
    @ObservedObject var messagesViewModel: MessagesViewModel
    @ObservedObject var todosViewModel: TodosViewModel
    @ObservedObject var profileViewModel: ProfileViewModel

    /// Factory for creating TopicDetailViewModels
    var topicDetailViewModelFactory: ((Topic) -> TopicDetailViewModel)?

    var body: some View {
        Group {
            switch authStateManager.currentState {
            case .unauthenticated, .authenticating:
                LoginView(authStateManager: authStateManager)
            case .authenticated:
                MainTabView(
                    forumViewModel: forumViewModel,
                    messagesViewModel: messagesViewModel,
                    todosViewModel: todosViewModel,
                    profileViewModel: profileViewModel,
                    topicDetailViewModelFactory: topicDetailViewModelFactory
                )
            case .failed(let error):
                ErrorView(error: error, authStateManager: authStateManager)
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
                .font(.title)
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

#Preview {
    let credentialStore = InMemoryCredentialStore()
    let authRepository = FakeAuthRepository(credentialStore: credentialStore)
    let fakeDiscourseRepo = FakeDiscourseRepository()

    return RootView(
        authStateManager: AuthStateManager(authRepository: authRepository),
        forumViewModel: ForumViewModel(discourseRepository: fakeDiscourseRepo),
        messagesViewModel: MessagesViewModel(
            discourseRepository: fakeDiscourseRepo,
            authRepository: authRepository
        ),
        todosViewModel: TodosViewModel(todoRepository: FakeTodoRepository()),
        profileViewModel: ProfileViewModel(authRepository: authRepository),
        topicDetailViewModelFactory: { topic in
            TopicDetailViewModel(topic: topic, discourseRepository: fakeDiscourseRepo)
        }
    )
}
