//
//  AppState.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import Foundation

/// Represents the authentication state of the application
enum AppState: Equatable {
    /// User is not authenticated
    case loggedOut

    /// Authentication is in progress
    case loggingIn

    /// User is successfully authenticated
    case loggedIn

    /// Authentication error occurred
    case error(String)

    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.loggedOut, .loggedOut),
             (.loggingIn, .loggingIn),
             (.loggedIn, .loggedIn):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}
