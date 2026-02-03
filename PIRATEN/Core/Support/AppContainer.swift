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
    /// Currently uses FakeTodoRepository; will be swapped for real meine-piraten.de API later.
    let todoRepository: TodoRepository

    // MARK: - Presentation Layer (ViewModels)

    /// Authentication state manager (ViewModel for auth flow).
    let authStateManager: AuthStateManager

    /// Forum view model for displaying topics.
    let forumViewModel: ForumViewModel

    /// Messages view model for displaying private message threads.
    let messagesViewModel: MessagesViewModel

    /// Todos view model for displaying tasks.
    let todosViewModel: TodosViewModel

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

        // HTTP layer for Discourse API
        // Use DiscourseHTTPClient which adds User-Api-Key headers for Discourse auth
        let baseHTTPClient = URLSessionHTTPClient()
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

        self.todoRepository = FakeTodoRepository()

        // Remaining presentation layer
        self.forumViewModel = ForumViewModel(discourseRepository: discourseRepository)
        self.messagesViewModel = MessagesViewModel(
            discourseRepository: discourseRepository,
            authRepository: authRepository
        )
        self.todosViewModel = TodosViewModel(todoRepository: todoRepository)
        self.profileViewModel = ProfileViewModel(authRepository: authRepository)
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

        // Storage layer (use standard UserDefaults for testing)
        self.recentRecipientsStore = RecentRecipientsStore()
        self.messageDraftStore = MessageDraftStore()

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
        self.profileViewModel = ProfileViewModel(authRepository: self.authRepository)
    }
}
