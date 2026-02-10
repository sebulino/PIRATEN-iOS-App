//
//  TodoAPIError.swift
//  PIRATEN
//
//  Created by Claude Code on 10.02.26.
//

import Foundation

/// API-level errors for meine-piraten.de Todo operations.
enum TodoAPIError: Error, Equatable {
    case notFound
    case validationFailed(message: String?)
    case serverError(message: String?)
    case networkError(message: String)
    case decodingError(message: String)
    case cancelled
    case unknown(statusCode: Int?, message: String?)

    var localizedDescription: String {
        switch self {
        case .notFound:
            return "Aufgabe nicht gefunden"
        case .validationFailed(let message):
            if let message = message {
                return "Validierungsfehler: \(message)"
            }
            return "Validierungsfehler"
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
