//
//  DiscourseAPIKeyProvider.swift
//  PIRATEN
//
//  Created by Claude Code on 02.02.26.
//

import Foundation

/// Protocol for providing Discourse User API Key credentials.
/// This abstraction allows different storage backends and facilitates testing.
protocol DiscourseAPIKeyProvider: Sendable {
    /// Retrieves the stored Discourse API key credential.
    /// - Returns: The stored credential
    /// - Throws: DiscourseAuthError.notAuthenticated if no credential exists
    func getAPIKey() async throws -> DiscourseCredential

    /// Checks if a valid credential exists.
    /// - Returns: true if a credential is stored, false otherwise
    func hasValidCredential() -> Bool
}
