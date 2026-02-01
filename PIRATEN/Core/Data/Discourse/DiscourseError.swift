//
//  DiscourseError.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation

/// Domain-level errors for Discourse API operations.
/// These errors are user-facing and should provide helpful messages.
enum DiscourseError: Error, Equatable {
    /// User is not authenticated or token is invalid (401)
    case unauthorized

    /// User does not have permission for this action (403)
    case forbidden

    /// The requested resource was not found (404)
    case notFound

    /// Too many requests - rate limit exceeded (429)
    case rateLimited

    /// Server-side error (5xx)
    case serverError(message: String?)

    /// Network connectivity issue
    case networkError(message: String)

    /// Response could not be decoded
    case decodingError(message: String)

    /// Request was cancelled
    case cancelled

    /// Unknown error with optional details
    case unknown(statusCode: Int?, message: String?)

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

    /// Whether this error is recoverable by retrying
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .networkError, .serverError:
            return true
        default:
            return false
        }
    }

    /// German localized description for user display
    var localizedDescription: String {
        switch self {
        case .unauthorized:
            return "Sitzung abgelaufen - bitte erneut anmelden"
        case .forbidden:
            return "Keine Berechtigung für diesen Bereich"
        case .notFound:
            return "Inhalt nicht gefunden"
        case .rateLimited:
            return "Zu viele Anfragen - bitte kurz warten"
        case .serverError(let message):
            if let message = message {
                return "Serverfehler: \(message)"
            }
            return "Serverfehler - bitte später erneut versuchen"
        case .networkError(let message):
            return "Netzwerkfehler: \(message)"
        case .decodingError:
            return "Daten konnten nicht verarbeitet werden"
        case .cancelled:
            return "Anfrage abgebrochen"
        case .unknown(_, let message):
            if let message = message {
                return "Fehler: \(message)"
            }
            return "Ein unbekannter Fehler ist aufgetreten"
        }
    }
}
