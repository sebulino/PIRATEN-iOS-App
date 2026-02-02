//
//  DiscourseCredential.swift
//  PIRATEN
//
//  Created by Claude Code on 02.02.26.
//

import Foundation

/// Represents the stored Discourse User API Key credential.
/// This is persisted in Keychain and used for authenticating Discourse API requests.
///
/// ## Security
/// - The API key is stored encrypted in Keychain
/// - The clientId ties this credential to the requesting application
/// - createdAt can be used for key rotation policies
struct DiscourseCredential: Codable, Sendable, Equatable {
    /// The Discourse User API Key for authenticating requests
    let apiKey: String

    /// The client ID that was used when requesting this key
    let clientId: String

    /// When this credential was created/obtained
    let createdAt: Date
}
