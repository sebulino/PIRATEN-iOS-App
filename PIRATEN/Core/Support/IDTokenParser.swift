//
//  IDTokenParser.swift
//  PIRATEN
//
//  Created by Claude Code on 02.02.26.
//

import Foundation

/// Parsed claims from an OIDC ID token (JWT).
/// Contains standard OIDC claims that Keycloak provides.
struct IDTokenClaims: Equatable {
    /// Subject identifier (unique user ID from Keycloak)
    let sub: String

    /// Preferred username (Keycloak username, used for Discourse)
    let preferredUsername: String?

    /// User's display name
    let name: String?

    /// User's email address
    let email: String?

    /// Whether email has been verified
    let emailVerified: Bool?
}

/// Parses OIDC ID tokens (JWTs) to extract user claims.
///
/// Note: This parser only decodes the payload - it does NOT verify the signature.
/// Signature verification is handled by AppAuth during the token exchange.
enum IDTokenParser {

    /// Decoding errors that can occur when parsing an ID token.
    enum ParsingError: Error, Equatable {
        case invalidFormat
        case base64DecodingFailed
        case jsonDecodingFailed
        case missingRequiredClaim(String)
    }

    /// Parses an ID token JWT and extracts the claims.
    /// - Parameter idToken: The raw JWT string (header.payload.signature)
    /// - Returns: Parsed claims from the token
    /// - Throws: ParsingError if the token cannot be parsed
    static func parse(_ idToken: String) throws -> IDTokenClaims {
        // JWT format: header.payload.signature (base64url encoded)
        let parts = idToken.split(separator: ".")
        guard parts.count == 3 else {
            throw ParsingError.invalidFormat
        }

        // Decode the payload (middle part)
        let payloadBase64 = String(parts[1])
        guard let payloadData = base64UrlDecode(payloadBase64) else {
            throw ParsingError.base64DecodingFailed
        }

        // Parse JSON
        guard let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            throw ParsingError.jsonDecodingFailed
        }

        // Extract required claim: sub
        guard let sub = json["sub"] as? String else {
            throw ParsingError.missingRequiredClaim("sub")
        }

        // Extract optional claims
        let preferredUsername = json["preferred_username"] as? String
        let name = json["name"] as? String
        let email = json["email"] as? String
        let emailVerified = json["email_verified"] as? Bool

        return IDTokenClaims(
            sub: sub,
            preferredUsername: preferredUsername,
            name: name,
            email: email,
            emailVerified: emailVerified
        )
    }

    /// Decodes a base64url-encoded string to Data.
    /// Base64url uses '-' instead of '+' and '_' instead of '/'.
    private static func base64UrlDecode(_ string: String) -> Data? {
        // Convert base64url to standard base64
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed (base64 requires length to be multiple of 4)
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }
}
