//
//  MessageSafetyService.swift
//  PIRATEN
//
//  Created by Claude Code on 02.02.26.
//

import Foundation

/// Configuration constants for message safety constraints.
/// Centralized here for easy auditing and adjustment.
enum MessageSafetyConstants {
    /// Minimum message length (after trimming whitespace)
    static let minMessageLength = 1

    /// Maximum message length in characters
    /// Discourse default is ~32000 but we use a conservative limit for mobile
    static let maxMessageLength = 10_000

    /// Cooldown period after sending a message (in seconds)
    /// Prevents rapid repeated sends
    static let sendCooldownSeconds: TimeInterval = 3.0
}

/// Validation result for message content
enum MessageValidationResult: Equatable {
    case valid
    case tooShort
    case tooLong(currentLength: Int, maxLength: Int)
    case empty

    /// User-facing error message (German)
    var errorMessage: String? {
        switch self {
        case .valid:
            return nil
        case .empty:
            return "Bitte gib eine Nachricht ein."
        case .tooShort:
            return "Die Nachricht ist zu kurz."
        case .tooLong(let current, let max):
            return "Die Nachricht ist zu lang (\(current)/\(max) Zeichen)."
        }
    }

    var isValid: Bool {
        self == .valid
    }
}

/// Service responsible for safety rails on messaging write actions.
/// Implements rate limiting and input validation without logging sensitive content.
///
/// Privacy note: This service NEVER logs message content, user identifiers,
/// or any PII. Only validation states and rate-limit events are tracked.
@MainActor
final class MessageSafetyService {

    // MARK: - Rate Limiting State

    /// Whether a send operation is currently in flight
    private(set) var isSendInProgress: Bool = false

    /// Timestamp of the last successful send
    private var lastSendTime: Date?

    /// Whether we are in the cooldown period after a send
    var isInCooldown: Bool {
        guard let lastSend = lastSendTime else { return false }
        let elapsed = Date().timeIntervalSince(lastSend)
        return elapsed < MessageSafetyConstants.sendCooldownSeconds
    }

    /// Seconds remaining in the cooldown period (0 if not in cooldown)
    var cooldownSecondsRemaining: TimeInterval {
        guard let lastSend = lastSendTime else { return 0 }
        let elapsed = Date().timeIntervalSince(lastSend)
        let remaining = MessageSafetyConstants.sendCooldownSeconds - elapsed
        return max(0, remaining)
    }

    // MARK: - Validation

    /// Validates message content against safety constraints.
    /// - Parameter content: The raw message content (will be trimmed)
    /// - Returns: Validation result indicating if the message is valid
    ///
    /// Note: This method does NOT log the message content.
    func validate(content: String) -> MessageValidationResult {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .empty
        }

        if trimmed.count < MessageSafetyConstants.minMessageLength {
            return .tooShort
        }

        if trimmed.count > MessageSafetyConstants.maxMessageLength {
            return .tooLong(
                currentLength: trimmed.count,
                maxLength: MessageSafetyConstants.maxMessageLength
            )
        }

        return .valid
    }

    /// Returns the current character count and limit for display
    /// - Parameter content: The message content
    /// - Returns: Tuple of (current count, max allowed, is over limit)
    func characterCount(for content: String) -> (current: Int, max: Int, isOverLimit: Bool) {
        let count = content.trimmingCharacters(in: .whitespacesAndNewlines).count
        let max = MessageSafetyConstants.maxMessageLength
        return (count, max, count > max)
    }

    // MARK: - Rate Limiting

    /// Checks if a send operation is currently allowed.
    /// - Returns: `true` if sending is allowed, `false` if blocked by rate limit
    func canSend() -> Bool {
        !isSendInProgress && !isInCooldown
    }

    /// Marks the beginning of a send operation.
    /// Call this before initiating the API request.
    func willStartSend() {
        isSendInProgress = true
    }

    /// Marks the completion of a send operation.
    /// - Parameter success: Whether the send was successful
    ///
    /// If successful, starts the cooldown period.
    /// If failed, allows immediate retry (no cooldown).
    func didCompleteSend(success: Bool) {
        isSendInProgress = false
        if success {
            lastSendTime = Date()
        }
    }

    /// Resets the rate limiting state.
    /// Use when the user navigates away or the view is dismissed.
    func reset() {
        isSendInProgress = false
        lastSendTime = nil
    }
}
