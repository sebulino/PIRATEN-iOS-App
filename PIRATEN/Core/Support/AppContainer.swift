//
//  AppContainer.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Central composition root for all application dependencies.
/// This is the single place where dependencies are wired together.
/// ViewModels and other components receive their dependencies via initializers.
@MainActor
final class AppContainer {

    // MARK: - OIDC Configuration Constants

    /// Piratenlogin SSO issuer URL (Keycloak realm)
    private static let issuerURL = URL(string: "https://sso.piratenpartei.de/realms/Piratenlogin")!

    /// OAuth2 client ID for the iOS app (public client)
    private static let clientID = "piraten_ios_app"

    /// Redirect URI for OAuth callback
    private static let redirectURI = URL(string: "de.meine-piraten://oauth-callback")!

    /// Discourse forum base URL
    private static let discourseBaseURL = URL(string: "https://diskussion.piratenpartei.de")!

    // MARK: - Support Layer (System Wrappers)

    /// Credential storage backed by iOS Keychain.
    /// This is the only "singleton-like" component, as it wraps a system service.
    let credentialStore: CredentialStore

    // MARK: - OIDC Services

    /// OIDC discovery service for fetching configuration from the issuer
    let discoveryService: OIDCDiscoveryService

    /// OIDC authorization service for handling the OAuth flow
    let authService: AppAuthOIDCAuthService

    /// Token refresher for refreshing access tokens
    let tokenRefresher: TokenRefresher

    // MARK: - Discourse Authentication

    /// Discourse API key provider for retrieving stored credentials
    let discourseAPIKeyProvider: DiscourseAPIKeyProvider

    /// RSA key manager for Discourse auth encryption
    let rsaKeyManager: RSAKeyManager

    /// Discourse authentication manager for User API Key flow
    let discourseAuthManager: DiscourseAuthManager?

    /// Discourse authentication coordinator for managing the auth flow from UI
    let discourseAuthCoordinator: DiscourseAuthCoordinator

    // MARK: - Data Layer (Repositories)

    /// Authentication repository implementation using real OIDC/OAuth2.
    let authRepository: AuthRepository

    /// Discourse forum repository implementation.
    /// Uses RealDiscourseRepository with authenticated HTTP client.
    let discourseRepository: DiscourseRepository

    /// Todo repository implementation.
    /// Production uses RealTodoRepository (meine-piraten.de API); tests use FakeTodoRepository.
    let todoRepository: TodoRepository

    /// Knowledge repository implementation.
    /// Production uses RealKnowledgeRepository (GitHub API); tests use FakeKnowledgeRepository.
    let knowledgeRepository: KnowledgeRepository

    // MARK: - Presentation Layer (ViewModels)

    /// Authentication state manager (ViewModel for auth flow).
    let authStateManager: AuthStateManager

    /// Forum view model for displaying topics.
    let forumViewModel: ForumViewModel

    /// Messages view model for displaying private message threads.
    let messagesViewModel: MessagesViewModel

    /// Todos view model for displaying tasks.
    let todosViewModel: TodosViewModel

    /// Knowledge view model for displaying educational content.
    let knowledgeViewModel: KnowledgeViewModel

    /// Profile view model for displaying user information.
    /// Note: Currently displays PLACEHOLDER DATA until SSO integration.
    let profileViewModel: ProfileViewModel

    // MARK: - Storage Layer

    /// Recent recipients storage for message composition.
    /// Stores up to 10 recently messaged usernames.
    let recentRecipientsStore: RecentRecipientsStore

    /// Message draft storage for auto-saving in-progress messages.
    /// Stores a single draft that persists across app restarts.
    let messageDraftStore: MessageDraftStore

    /// Reading progress storage for Knowledge Hub topics.
    let readingProgressStore: ReadingProgressStore

    /// Device token manager for APNs registration and storage.
    /// Stores device tokens locally (non-sensitive data).
    let deviceTokenManager: DeviceTokenManager

    /// Notification settings manager for push notification preferences.
    /// Privacy-first: all notifications are opt-in (default off).
    let notificationSettingsManager: NotificationSettingsManager

    /// Deep link router for handling notification-based navigation.
    let deepLinkRouter: DeepLinkRouter

    // MARK: - ViewModel Factories

    /// Creates a TopicDetailViewModel for the given topic.
    /// Used for navigating from topic list to detail view.
    /// - Parameter topic: The topic to display in detail
    /// - Returns: A configured TopicDetailViewModel
    func makeTopicDetailViewModel(for topic: Topic) -> TopicDetailViewModel {
        TopicDetailViewModel(topic: topic, discourseRepository: discourseRepository)
    }

    /// Creates a MessageThreadDetailViewModel for the given message thread.
    /// Used for navigating from message list to thread detail view.
    /// - Parameter thread: The message thread to display in detail
    /// - Returns: A configured MessageThreadDetailViewModel
    func makeMessageThreadDetailViewModel(for thread: MessageThread) -> MessageThreadDetailViewModel {
        MessageThreadDetailViewModel(thread: thread, discourseRepository: discourseRepository)
    }

    /// Creates a RecipientPickerViewModel for composing new messages.
    /// - Returns: A configured RecipientPickerViewModel
    func makeRecipientPickerViewModel() -> RecipientPickerViewModel {
        RecipientPickerViewModel(
            discourseRepository: discourseRepository,
            recentRecipientsStorage: recentRecipientsStore
        )
    }

    /// Creates a ComposeMessageViewModel for composing new messages.
    /// - Returns: A configured ComposeMessageViewModel
    func makeComposeMessageViewModel() -> ComposeMessageViewModel {
        ComposeMessageViewModel(
            discourseRepository: discourseRepository,
            recentRecipientsStorage: recentRecipientsStore,
            draftStorage: messageDraftStore
        )
    }

    /// Creates a UserProfileViewModel for the given username.
    /// Used for displaying user profiles when tapping usernames in forum posts and messages.
    /// - Parameter username: The username to fetch the profile for
    /// - Returns: A configured UserProfileViewModel
    func makeUserProfileViewModel(username: String) -> UserProfileViewModel {
        UserProfileViewModel(username: username, discourseRepository: discourseRepository)
    }

    /// Creates a CreateTodoViewModel for the create todo form.
    /// - Returns: A configured CreateTodoViewModel
    func makeCreateTodoViewModel() -> CreateTodoViewModel {
        CreateTodoViewModel(todoRepository: todoRepository)
    }

    /// Creates a KnowledgeTopicDetailViewModel for the given topic.
    /// - Parameter topic: The topic to display in detail
    /// - Returns: A configured KnowledgeTopicDetailViewModel
    func makeKnowledgeTopicDetailViewModel(for topic: KnowledgeTopic) -> KnowledgeTopicDetailViewModel {
        KnowledgeTopicDetailViewModel(
            topic: topic,
            repository: knowledgeRepository,
            progressStore: readingProgressStore
        )
    }

    /// Creates a TodoDetailViewModel for the given todo.
    /// - Parameter todo: The todo to display in detail
    /// - Returns: A configured TodoDetailViewModel
    func makeTodoDetailViewModel(for todo: Todo) -> TodoDetailViewModel {
        TodoDetailViewModel(todo: todo, todoRepository: todoRepository)
    }

    /// Creates an AdminRequestViewModel for requesting admin access.
    /// - Returns: A configured AdminRequestViewModel
    func makeAdminRequestViewModel() -> AdminRequestViewModel {
        AdminRequestViewModel(todoRepository: todoRepository)
    }

    // MARK: - Initialization

    /// Creates the container with default production dependencies.
    init() {
        // Support layer
        self.credentialStore = KeychainCredentialStore()

        // OIDC services
        self.discoveryService = AppAuthOIDCDiscoveryService(issuerURL: Self.issuerURL)
        self.authService = AppAuthOIDCAuthService(
            clientID: Self.clientID,
            redirectURI: Self.redirectURI,
            scopes: ["openid", "profile", "offline_access"]
        )
        self.tokenRefresher = AppAuthTokenRefresher(clientID: Self.clientID)

        // Data layer - real OIDC auth repository
        self.authRepository = OIDCAuthRepository(
            discoveryService: discoveryService,
            authService: authService,
            tokenRefresher: tokenRefresher,
            credentialStore: credentialStore
        )

        // Storage layer
        self.recentRecipientsStore = RecentRecipientsStore()
        self.messageDraftStore = MessageDraftStore()
        self.readingProgressStore = ReadingProgressStore()

        // Push notification layer
        self.deviceTokenManager = DeviceTokenManager()
        self.notificationSettingsManager = NotificationSettingsManager(deviceTokenManager: deviceTokenManager)
        self.deepLinkRouter = DeepLinkRouter()

        // Presentation layer - auth state manager first (needed for HTTP client)
        self.authStateManager = AuthStateManager(
            authRepository: authRepository,
            recentRecipientsStorage: recentRecipientsStore
        )

        // Discourse authentication layer
        self.rsaKeyManager = RSAKeyManager()
        self.discourseAPIKeyProvider = KeychainDiscourseAPIKeyProvider(credentialStore: credentialStore)

        // Initialize Discourse auth manager (may fail if config is missing)
        var authManager: DiscourseAuthManager?
        do {
            authManager = try DiscourseAuthManager(rsaKeyManager: rsaKeyManager)
        } catch {
            // Configuration not available - Discourse auth will not be available
            // This is acceptable during development or if Discourse is not configured
            authManager = nil
        }
        self.discourseAuthManager = authManager

        // Discourse auth coordinator for managing auth flow from UI
        self.discourseAuthCoordinator = DiscourseAuthCoordinator(
            discourseAuthManager: authManager,
            discourseAPIKeyProvider: discourseAPIKeyProvider,
            credentialStore: credentialStore
        )

        // HTTP layer
        // Caching session (see D-025) + retry wrapper for transient failures (see D-024)
        let rawHTTPClient = URLSessionHTTPClient.withCaching()
        let baseHTTPClient = RetryingHTTPClient(wrapped: rawHTTPClient)

        // Discourse HTTP client adds User-Api-Key headers for Discourse auth
        let discourseHTTPClient = DiscourseHTTPClient(
            baseClient: baseHTTPClient,
            apiKeyProvider: discourseAPIKeyProvider
        )

        // Discourse API client and repository
        let discourseAPIClient = DiscourseAPIClient(
            httpClient: discourseHTTPClient,
            baseURL: Self.discourseBaseURL
        )
        self.discourseRepository = RealDiscourseRepository(apiClient: discourseAPIClient)

        // meine-piraten.de API client and repository
        // Base URL read from Info.plist (set via xcconfig MEINE_PIRATEN_BASE_URL)
        let meinePiratenBaseURL: URL
        if let urlString = Bundle.main.infoDictionary?["MEINE_PIRATEN_BASE_URL"] as? String,
           let url = URL(string: urlString) {
            meinePiratenBaseURL = url
        } else {
            // Fallback for development — should not happen in production
            meinePiratenBaseURL = URL(string: "https://meine-piraten.de")!
        }
        let todoTokenProvider = AuthStateTokenProvider(authStateManager: authStateManager)
        let todoHTTPClient = AuthenticatedHTTPClient(
            baseClient: baseHTTPClient,
            tokenProvider: todoTokenProvider,
            onAuthError: { [weak authStateManager] in
                Task { @MainActor in
                    authStateManager?.handleAuthenticationError()
                }
            }
        )
        let todoAPIClient = TodoAPIClient(httpClient: todoHTTPClient, baseURL: meinePiratenBaseURL)
        self.todoRepository = RealTodoRepository(apiClient: todoAPIClient, authRepository: authRepository)

        // Knowledge Hub - GitHub API client and repository
        // Repo config read from Info.plist (set via xcconfig)
        let knowledgeRepoOwner = Bundle.main.infoDictionary?["KNOWLEDGE_REPO_OWNER"] as? String ?? "sebulino"
        let knowledgeRepoName = Bundle.main.infoDictionary?["KNOWLEDGE_REPO_NAME"] as? String ?? "PIRATEN-Kanon"
        let knowledgeRepoBranch = Bundle.main.infoDictionary?["KNOWLEDGE_REPO_BRANCH"] as? String ?? "main"
        let gitHubAPIClient = GitHubAPIClient(
            httpClient: baseHTTPClient,
            repoOwner: knowledgeRepoOwner,
            repoName: knowledgeRepoName,
            branch: knowledgeRepoBranch
        )
        let knowledgeCacheManager = KnowledgeCacheManager()
        let realKnowledgeRepository = RealKnowledgeRepository(
            apiClient: gitHubAPIClient,
            cacheManager: knowledgeCacheManager
        )
        self.knowledgeRepository = realKnowledgeRepository

        // Remaining presentation layer
        self.forumViewModel = ForumViewModel(discourseRepository: discourseRepository)
        self.messagesViewModel = MessagesViewModel(
            discourseRepository: discourseRepository,
            authRepository: authRepository
        )
        self.todosViewModel = TodosViewModel(todoRepository: todoRepository)
        self.knowledgeViewModel = KnowledgeViewModel(
            repository: realKnowledgeRepository,
            progressStore: readingProgressStore
        )
        self.profileViewModel = ProfileViewModel(authRepository: authRepository, discourseRepository: discourseRepository)
    }

    /// Creates the container with custom dependencies for testing.
    /// - Parameters:
    ///   - credentialStore: Custom credential store implementation
    ///   - authRepositoryFactory: Factory closure to create auth repository with the credential store
    ///   - discourseRepository: Custom discourse repository implementation (defaults to fake)
    ///   - todoRepository: Custom todo repository implementation (defaults to fake)
    init(
        credentialStore: CredentialStore,
        authRepositoryFactory: ((CredentialStore) -> AuthRepository)? = nil,
        discourseRepository: DiscourseRepository? = nil,
        todoRepository: TodoRepository? = nil
    ) {
        self.credentialStore = credentialStore

        // OIDC services (still needed for testing container consistency)
        self.discoveryService = AppAuthOIDCDiscoveryService(issuerURL: Self.issuerURL)
        self.authService = AppAuthOIDCAuthService(
            clientID: Self.clientID,
            redirectURI: Self.redirectURI,
            scopes: ["openid", "profile", "offline_access"]
        )
        self.tokenRefresher = AppAuthTokenRefresher(clientID: Self.clientID)

        if let factory = authRepositoryFactory {
            self.authRepository = factory(credentialStore)
        } else {
            self.authRepository = FakeAuthRepository(credentialStore: credentialStore)
        }

        // Discourse authentication (for testing, use in-memory store)
        self.rsaKeyManager = RSAKeyManager()
        self.discourseAPIKeyProvider = KeychainDiscourseAPIKeyProvider(credentialStore: credentialStore)
        self.discourseAuthManager = nil  // Not needed for testing with fake repositories
        self.discourseAuthCoordinator = DiscourseAuthCoordinator(
            discourseAuthManager: nil,
            discourseAPIKeyProvider: discourseAPIKeyProvider,
            credentialStore: credentialStore
        )

        self.discourseRepository = discourseRepository ?? FakeDiscourseRepository()
        self.todoRepository = todoRepository ?? FakeTodoRepository()
        self.knowledgeRepository = FakeKnowledgeRepository()

        // Storage layer (use standard UserDefaults for testing)
        self.recentRecipientsStore = RecentRecipientsStore()
        self.messageDraftStore = MessageDraftStore()
        self.readingProgressStore = ReadingProgressStore()

        // Push notification layer (testing)
        self.deviceTokenManager = DeviceTokenManager()
        self.notificationSettingsManager = NotificationSettingsManager(deviceTokenManager: deviceTokenManager)
        self.deepLinkRouter = DeepLinkRouter()

        self.authStateManager = AuthStateManager(
            authRepository: authRepository,
            recentRecipientsStorage: recentRecipientsStore
        )
        self.forumViewModel = ForumViewModel(discourseRepository: self.discourseRepository)
        self.messagesViewModel = MessagesViewModel(
            discourseRepository: self.discourseRepository,
            authRepository: self.authRepository
        )
        self.todosViewModel = TodosViewModel(todoRepository: self.todoRepository)
        self.knowledgeViewModel = KnowledgeViewModel(
            repository: knowledgeRepository,
            progressStore: readingProgressStore
        )
        self.profileViewModel = ProfileViewModel(authRepository: self.authRepository, discourseRepository: self.discourseRepository)
    }
}
