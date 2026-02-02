//
//  PIRATENApp.swift
//  PIRATEN
//
//  Created by Sebulino on 29.01.26.
//

import SwiftUI

@main
struct PIRATENApp: App {
    /// The central dependency container for the application.
    /// All dependencies are constructed here and injected into the view hierarchy.
    private let container: AppContainer

    init() {
        self.container = AppContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                authStateManager: container.authStateManager,
                forumViewModel: container.forumViewModel,
                messagesViewModel: container.messagesViewModel,
                todosViewModel: container.todosViewModel,
                profileViewModel: container.profileViewModel,
                discourseAuthCoordinator: container.discourseAuthCoordinator,
                topicDetailViewModelFactory: { [container] topic in
                    container.makeTopicDetailViewModel(for: topic)
                },
                messageThreadDetailViewModelFactory: { [container] thread in
                    container.makeMessageThreadDetailViewModel(for: thread)
                }
            )
            .onOpenURL { url in
                // Piratenlogin OAuth callback only
                if url.host == "oauth-callback" {
                    _ = container.authService.resumeAuthorizationFlow(with: url)
                }
            }
        }
    }
}
