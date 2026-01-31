//
//  HTTPError.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

/// Domain-level HTTP errors for API communication.
/// These errors are abstracted from URLSession implementation details.
enum HTTPError: Error, Equatable {
    /// Server returned 401 Unauthorized - token is invalid or expired
    case unauthorized

    /// Server returned 403 Forbidden - insufficient permissions
    case forbidden

    /// Server returned 404 Not Found
    case notFound

    /// Server returned an error status code (4xx or 5xx)
    case serverError(statusCode: Int, message: String?)

    /// Request failed due to network issues
    case networkError(String)

    /// Response body could not be decoded
    case decodingError(String)

    /// Request was cancelled
    case cancelled

    /// Unknown or unexpected error
    case unknown(String)

    /// Whether this error indicates an authentication problem
    /// that should trigger re-authentication
    var isAuthenticationError: Bool {
        switch self {
        case .unauthorized, .forbidden:
            return true
        default:
            return false
        }
    }

    var localizedDescription: String {
        switch self {
        case .unauthorized:
            return "Nicht autorisiert - bitte erneut anmelden"
        case .forbidden:
            return "Zugriff verweigert"
        case .notFound:
            return "Ressource nicht gefunden"
        case .serverError(let statusCode, let message):
            if let message = message {
                return "Serverfehler (\(statusCode)): \(message)"
            }
            return "Serverfehler (\(statusCode))"
        case .networkError(let message):
            return "Netzwerkfehler: \(message)"
        case .decodingError(let message):
            return "Datenverarbeitung fehlgeschlagen: \(message)"
        case .cancelled:
            return "Anfrage abgebrochen"
        case .unknown(let message):
            return "Unbekannter Fehler: \(message)"
        }
    }
}
