//
//  PIRATENApp.swift
//  PIRATEN
//
//  Created by Sebulino on 29.01.26.
//

import SwiftUI

@main
struct PIRATENApp: App {
    /// App delegate for handling notification routing
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// The central dependency container for the application.
    /// All dependencies are constructed here and injected into the view hierarchy.
    private let container: AppContainer

    init() {
        // Configure custom fonts for navigation bars
        PiratenAppearance.configure()

        // Check for UI testing mode - reset auth state for clean test environment
        if CommandLine.arguments.contains("-UITestMode") {
            Self.resetAuthStateForUITesting()
        }

        #if DEBUG
        // ScreenshotMode: use the test AppContainer init (fake repos with
        // rich placeholder data) and auto-authenticate, so App Store
        // screenshot tooling can capture every tab without needing a real
        // SSO account. Strictly DEBUG-only — the symbol does not exist
        // in Release builds.
        if CommandLine.arguments.contains("-ScreenshotMode") {
            let store = InMemoryCredentialStore()
            // Pre-populate a fake Discourse credential so HomeViewModel
            // takes the "Discourse connected" branch instead of showing
            // the "verbinde dich mit dem Forum" empty state. The credential
            // is never used to talk to a server — FakeDiscourseRepository
            // ignores it — but the gate `discourseAPIKeyProvider.hasValidCredential()`
            // needs to see *something* in the store.
            Self.seedFakeDiscourseCredential(into: store)
            let container = AppContainer(credentialStore: store)
            self.container = container
            AppContainer.shared = container
            appDelegate.deepLinkRouter = container.deepLinkRouter
            Task { @MainActor [container] in
                container.authStateManager.authenticate()
            }
            return
        }
        #endif

        self.container = AppContainer()
        AppContainer.shared = container

        // Wire AppDelegate to DeepLinkRouter for notification routing
        appDelegate.deepLinkRouter = container.deepLinkRouter
    }

    #if DEBUG
    /// Writes a fake Discourse credential to the in-memory store used in
    /// ScreenshotMode. Same JSON format the production
    /// `KeychainDiscourseAPIKeyProvider.getAPIKey()` decodes, so the gate
    /// `hasValidCredential()` returns true and HomeViewModel exercises
    /// the populated branch.
    private static func seedFakeDiscourseCredential(into store: CredentialStore) {
        let credential = DiscourseCredential(
            apiKey: "screenshot-mode-fake-key",
            clientId: "screenshot-mode-fake-client",
            createdAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(credential),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        try? store.set(json, forKey: DiscourseAuthManager.discourseCredentialKey)
    }
    #endif

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
                homeViewModel: container.homeViewModel,
                forumViewModel: container.forumViewModel,
                newsViewModel: container.newsViewModel,
                messagesViewModel: container.messagesViewModel,
                knowledgeViewModel: container.knowledgeViewModel,
                calendarViewModel: container.calendarViewModel,
                todosViewModel: container.todosViewModel,
                profileViewModel: container.profileViewModel,
                discourseAuthCoordinator: container.discourseAuthCoordinator,
                notificationSettings: container.notificationSettingsManager,
                notificationPoller: container.notificationPoller,
                deepLinkRouter: container.deepLinkRouter,
                eventKitService: container.eventKitService,
                avatarImageCache: container.avatarImageCache,
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
                },
                createTodoViewModelFactory: { [container] in
                    container.makeCreateTodoViewModel()
                },
                knowledgeTopicDetailViewModelFactory: { [container] topic in
                    container.makeKnowledgeTopicDetailViewModel(for: topic)
                },
                todoDetailViewModelFactory: { [container] todo in
                    container.makeTodoDetailViewModel(for: todo)
                },
                feedbackViewModelFactory: { [container] type in
                    container.makeFeedbackViewModel(type: type)
                },
                adminRequestViewModelFactory: { [container] in
                    container.makeAdminRequestViewModel()
                },
                checkAdminStatus: { [container] in
                    await container.todoRepository.checkAdminStatus()
                },
                onLogout: { [container] in
                    // Logout is wired through AuthStateManager.logoutHook
                    // → LogoutOrchestrator (security audit H-2).
                    // See AppContainer init for the wiring.
                    container.authStateManager.logout()
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
