//
//  AuthState.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Represents the authentication state of the application.
/// This is the domain model for auth state - UI should depend only on this.
enum AuthState: Equatable {
    /// User is not authenticated (initial state or after logout)
    case unauthenticated

    /// Authentication is in progress
    case authenticating

    /// User is successfully authenticated
    case authenticated

    /// Authentication failed with an error
    case failed(AuthError)
}

/// Domain-level authentication errors
enum AuthError: Error, Equatable {
    case invalidCredentials
    case networkError(String)
    case serverError(String)
    case unknown(String)

    var localizedDescription: String {
        switch self {
        case .invalidCredentials:
            return "Ungültige Anmeldedaten"
        case .networkError(let message):
            return "Netzwerkfehler: \(message)"
        case .serverError(let message):
            return "Serverfehler: \(message)"
        case .unknown(let message):
            return "Unbekannter Fehler: \(message)"
        }
    }
}
