//
//  RetryingHTTPClient.swift
//  PIRATEN
//
//  Created by Claude Code on 13.02.26.
//

import Foundation

/// HTTP client wrapper that retries transient failures with exponential backoff.
/// Wraps any HTTPClient and adds bounded retry behavior for retryable errors.
///
/// Policy (see D-024):
/// - Max 3 attempts (1 initial + 2 retries)
/// - Exponential backoff: 1s, 2s between retries
/// - Only retries on transient errors (network errors, server 5xx)
/// - Non-retryable errors (auth, not found, decoding) fail immediately
/// - Only retries GET requests (mutations are not safe to retry)
final class RetryingHTTPClient: HTTPClient, @unchecked Sendable {
    private let wrapped: HTTPClient
    private let maxAttempts: Int
    private let baseDelay: TimeInterval

    init(
        wrapped: HTTPClient,
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0
    ) {
        self.wrapped = wrapped
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        // Only retry GET requests; mutations are not idempotent
        guard request.method == .get else {
            return try await wrapped.execute(request)
        }

        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                return try await wrapped.execute(request)
            } catch let error as HTTPError where error.isRetryable {
                lastError = error

                // Don't sleep after the last attempt
                if attempt < maxAttempts - 1 {
                    let delay = baseDelay * pow(2.0, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                // Non-retryable error, fail immediately
                throw error
            }
        }

        throw lastError ?? HTTPError.unknown("All retry attempts exhausted")
    }
}
