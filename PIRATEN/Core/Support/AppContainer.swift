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

    // MARK: - Support Layer (System Wrappers)

    /// Credential storage backed by iOS Keychain.
    /// This is the only "singleton-like" component, as it wraps a system service.
    let credentialStore: CredentialStore

    // MARK: - Data Layer (Repositories)

    /// Authentication repository implementation.
    /// Currently uses FakeAuthRepository; will be swapped for real SSO implementation later.
    let authRepository: AuthRepository

    /// Discourse forum repository implementation.
    /// Currently uses FakeDiscourseRepository; will be swapped for real Discourse API later.
    let discourseRepository: DiscourseRepository

    /// Todo repository implementation.
    /// Currently uses FakeTodoRepository; will be swapped for real meine-piraten.de API later.
    let todoRepository: TodoRepository

    // MARK: - Presentation Layer (ViewModels)

    /// Authentication state manager (ViewModel for auth flow).
    let authStateManager: AuthStateManager

    /// Forum view model for displaying topics.
    let forumViewModel: ForumViewModel

    /// Todos view model for displaying tasks.
    let todosViewModel: TodosViewModel

    /// Profile view model for displaying user information.
    /// Note: Currently displays PLACEHOLDER DATA until SSO integration.
    let profileViewModel: ProfileViewModel

    // MARK: - Initialization

    /// Creates the container with default production dependencies.
    init() {
        // Support layer
        self.credentialStore = KeychainCredentialStore()

        // Data layer
        self.authRepository = FakeAuthRepository(credentialStore: credentialStore)
        self.discourseRepository = FakeDiscourseRepository()
        self.todoRepository = FakeTodoRepository()

        // Presentation layer
        self.authStateManager = AuthStateManager(authRepository: authRepository)
        self.forumViewModel = ForumViewModel(discourseRepository: discourseRepository)
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

        if let factory = authRepositoryFactory {
            self.authRepository = factory(credentialStore)
        } else {
            self.authRepository = FakeAuthRepository(credentialStore: credentialStore)
        }

        self.discourseRepository = discourseRepository ?? FakeDiscourseRepository()
        self.todoRepository = todoRepository ?? FakeTodoRepository()

        self.authStateManager = AuthStateManager(authRepository: authRepository)
        self.forumViewModel = ForumViewModel(discourseRepository: self.discourseRepository)
        self.todosViewModel = TodosViewModel(todoRepository: self.todoRepository)
        self.profileViewModel = ProfileViewModel(authRepository: self.authRepository)
    }
}
