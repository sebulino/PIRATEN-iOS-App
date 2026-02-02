//
//  DiscourseAuthResponse.swift
//  PIRATEN
//
//  Created by Claude Code on 02.02.26.
//

import Foundation

/// The decrypted response from Discourse User API Key authentication.
/// This is the structure inside the encrypted payload returned by Discourse.
///
/// Reference: https://meta.discourse.org/t/user-api-keys-specification/48536
struct DiscourseAuthResponse: Decodable, Equatable {
    /// The User API Key to use for authenticated requests
    let key: String

    /// The nonce that was sent in the auth request, for verification
    let nonce: String
}
