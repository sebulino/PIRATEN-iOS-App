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
    @ObservedObject var todosViewModel: TodosViewModel
    @ObservedObject var profileViewModel: ProfileViewModel

    var body: some View {
        Group {
            switch authStateManager.currentState {
            case .unauthenticated, .authenticating:
                LoginView(authStateManager: authStateManager)
            case .authenticated:
                MainTabView(
                    forumViewModel: forumViewModel,
                    todosViewModel: todosViewModel,
                    profileViewModel: profileViewModel
                )
            case .failed(let error):
                ErrorView(error: error, authStateManager: authStateManager)
            }
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

    return RootView(
        authStateManager: AuthStateManager(authRepository: authRepository),
        forumViewModel: ForumViewModel(discourseRepository: FakeDiscourseRepository()),
        todosViewModel: TodosViewModel(todoRepository: FakeTodoRepository()),
        profileViewModel: ProfileViewModel(authRepository: authRepository)
    )
}
