//
//  LogRedactor.swift
//  PIRATEN
//
//  Created by Claude Code on 12.02.26.
//

import Foundation

/// Centralized redaction utilities for safe logging.
///
/// All logging of potentially sensitive values MUST use these helpers
/// to prevent accidental exposure of tokens, keys, credentials, or PII
/// in device logs, crash reports, or Console.app output.
///
/// ## Usage
/// ```swift
/// logger.info("Token: \(LogRedactor.redactSecret(token))")
/// logger.info("URL: \(LogRedactor.redactURL(callbackURL))")
/// ```
enum LogRedactor {

    /// Redacts a secret value, showing only a short prefix for identification.
    /// Returns `"<redacted>"` for nil or empty strings.
    ///
    /// - Parameters:
    ///   - value: The secret string (token, key, nonce, etc.)
    ///   - prefixLength: Number of leading characters to keep (default 8)
    /// - Returns: A safe-to-log string like `"abc12345…(128 chars)"`
    static func redactSecret(_ value: String?, prefixLength: Int = 8) -> String {
        guard let value, !value.isEmpty else { return "<redacted>" }
        let safePrefix = String(value.prefix(prefixLength))
        return "\(safePrefix)…(\(value.count) chars)"
    }

    /// Redacts a URL by stripping query parameters and fragments that may
    /// contain tokens, payloads, or other sensitive data.
    ///
    /// - Parameter url: The URL to redact
    /// - Returns: A safe-to-log string showing scheme + host + path only
    static func redactURL(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "<invalid-url>"
        }
        let paramCount = components.queryItems?.count ?? 0
        components.queryItems = nil
        components.fragment = nil
        let base = components.string ?? url.host ?? "<unknown>"
        return paramCount > 0 ? "\(base) [\(paramCount) params redacted]" : base
    }

    /// Redacts a Data payload, logging only its byte count.
    ///
    /// - Parameter data: The data payload
    /// - Returns: A safe-to-log string like `"<data: 256 bytes>"`
    static func redactData(_ data: Data?) -> String {
        guard let data else { return "<no data>" }
        return "<data: \(data.count) bytes>"
    }
}
