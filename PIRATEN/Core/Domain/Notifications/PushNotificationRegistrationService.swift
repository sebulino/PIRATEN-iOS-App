//
//  PushNotificationRegistrationService.swift
//  PIRATEN
//
//  Created by Claude Code on 08.03.26.
//

import Foundation

/// User's notification preferences by category.
/// Sent to backend when registering a device token.
struct PushNotificationPreferences: Equatable {
    /// Receive notifications for new private messages
    let messagesEnabled: Bool

    /// Receive notifications for new or updated todos
    let todosEnabled: Bool

    /// Receive notifications for new forum posts
    let forumEnabled: Bool
}

/// Protocol for registering and unregistering push notification device tokens
/// with the backend, along with per-category preferences.
///
/// The backend uses this to know:
/// - Which device to send notifications to (token)
/// - Which event types the user wants to receive
///
/// See: Docs/OPEN_QUESTIONS.md Q-014 for the pending backend endpoint.
protocol PushNotificationRegistrationService: AnyObject {
    /// Registers the device token with the backend and syncs preferences.
    /// Called when any preference changes or a new device token is received.
    /// - Parameters:
    ///   - token: APNs device token as hex string
    ///   - preferences: The user's current notification preferences
    func register(token: String, preferences: PushNotificationPreferences) async throws

    /// Unregisters the device token from the backend.
    /// Called when all notifications are disabled or the user logs out.
    /// - Parameter token: APNs device token as hex string
    func unregister(token: String) async throws
}
