//
//  PIRATENApp.swift
//  PIRATEN
//
//  Created by Sebulino on 29.01.26.
//

import SwiftUI

@main
struct PIRATENApp: App {
    /// App delegate for handling APNs device token callbacks
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// The central dependency container for the application.
    /// All dependencies are constructed here and injected into the view hierarchy.
    private let container: AppContainer

    init() {
        // Check for UI testing mode - reset auth state for clean test environment
        if CommandLine.arguments.contains("-UITestMode") {
            Self.resetAuthStateForUITesting()
        }

        self.container = AppContainer()

        // Wire AppDelegate to DeviceTokenManager for APNs callbacks
        appDelegate.deviceTokenManager = container.deviceTokenManager

        // Wire AppDelegate to DeepLinkRouter for notification routing
        appDelegate.deepLinkRouter = container.deepLinkRouter
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
            StartupContainerView(
                authStateManager: container.authStateManager,
                forumViewModel: container.forumViewModel,
                messagesViewModel: container.messagesViewModel,
                todosViewModel: container.todosViewModel,
                profileViewModel: container.profileViewModel,
                discourseAuthCoordinator: container.discourseAuthCoordinator,
                notificationSettings: container.notificationSettingsManager,
                deepLinkRouter: container.deepLinkRouter,
                topicDetailViewModelFactory: { [container] topic in
                    container.makeTopicDetailViewModel(for: topic)
                },
                messageThreadDetailViewModelFactory: { [container] thread in
                    container.makeMessageThreadDetailViewModel(for: thread)
                },
                recipientPickerViewModelFactory: { [container] in
                    container.makeRecipientPickerViewModel()
                },
                composeMessageViewModelFactory: { [container] in
                    container.makeComposeMessageViewModel()
                },
                userProfileViewModelFactory: { [container] username in
                    container.makeUserProfileViewModel(username: username)
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
