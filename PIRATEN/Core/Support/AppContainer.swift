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

    // MARK: - Presentation Layer (ViewModels)

    /// Authentication state manager (ViewModel for auth flow).
    let authStateManager: AuthStateManager

    // MARK: - Initialization

    /// Creates the container with default production dependencies.
    init() {
        // Support layer
        self.credentialStore = KeychainCredentialStore()

        // Data layer
        self.authRepository = FakeAuthRepository(credentialStore: credentialStore)

        // Presentation layer
        self.authStateManager = AuthStateManager(authRepository: authRepository)
    }

    /// Creates the container with custom dependencies for testing.
    /// - Parameters:
    ///   - credentialStore: Custom credential store implementation
    ///   - authRepositoryFactory: Factory closure to create auth repository with the credential store
    init(
        credentialStore: CredentialStore,
        authRepositoryFactory: ((CredentialStore) -> AuthRepository)? = nil
    ) {
        self.credentialStore = credentialStore

        if let factory = authRepositoryFactory {
            self.authRepository = factory(credentialStore)
        } else {
            self.authRepository = FakeAuthRepository(credentialStore: credentialStore)
        }

        self.authStateManager = AuthStateManager(authRepository: authRepository)
    }
}
