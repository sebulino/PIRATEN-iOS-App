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
        // Check for UI testing mode - reset auth state for clean test environment
        if CommandLine.arguments.contains("-UITestMode") {
            Self.resetAuthStateForUITesting()
        }

        self.container = AppContainer()
    }

    /// Resets authentication state for UI testing.
    /// Clears keychain credentials to ensure a clean logged-out state.
    private static func resetAuthStateForUITesting() {
        let keychain = KeychainCredentialStore()

        // Clear OIDC credentials (keys from OIDCAuthRepository)
        try? keychain.delete(forKey: "oidc_access_token")
        try? keychain.delete(forKey: "oidc_refresh_token")
        try? keychain.delete(forKey: "oidc_id_token")
        try? keychain.delete(forKey: "oidc_token_expiration")

        // Clear Discourse API key
        try? keychain.delete(forKey: DiscourseAuthManager.discourseCredentialKey)
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
