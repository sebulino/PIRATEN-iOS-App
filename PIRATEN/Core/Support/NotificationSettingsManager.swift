//
//  NotificationSettingsManager.swift
//  PIRATEN
//
//  Created by Claude Code on 03.02.26.
//

import Foundation
import UserNotifications
import Combine
import UIKit

/// Manages notification permissions and user preferences.
/// Privacy-first: All notifications are opt-in (default off).
/// No tracking or analytics data is collected.
@MainActor
final class NotificationSettingsManager: ObservableObject {

    // MARK: - Published State

    /// Whether message notifications are enabled by the user
    @Published var messagesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(messagesEnabled, forKey: Keys.messagesEnabled)
            if messagesEnabled {
                requestPermissionIfNeeded()
            }
        }
    }

    /// Whether todo notifications are enabled by the user
    @Published var todosEnabled: Bool {
        didSet {
            UserDefaults.standard.set(todosEnabled, forKey: Keys.todosEnabled)
            if todosEnabled {
                requestPermissionIfNeeded()
            }
        }
    }

    /// The current system authorization status
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Whether we're currently requesting permission
    @Published private(set) var isRequestingPermission = false

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let messagesEnabled = "notification_messages_enabled"
        static let todosEnabled = "notification_todos_enabled"
    }

    // MARK: - Initialization

    init() {
        // Load saved preferences (default to false for privacy)
        self.messagesEnabled = UserDefaults.standard.bool(forKey: Keys.messagesEnabled)
        self.todosEnabled = UserDefaults.standard.bool(forKey: Keys.todosEnabled)

        // Check current authorization status
        Task {
            await refreshAuthorizationStatus()
        }
    }

    // MARK: - Public Methods

    /// Refreshes the current authorization status from the system.
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
    }

    /// Whether any notification type is enabled
    var hasAnyNotificationsEnabled: Bool {
        messagesEnabled || todosEnabled
    }

    /// Whether system permission has been granted
    var isSystemPermissionGranted: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    /// Whether the user needs to grant system permission
    var needsSystemPermission: Bool {
        hasAnyNotificationsEnabled && !isSystemPermissionGranted
    }

    /// Requests system notification permission if not already granted.
    /// Only called when user explicitly enables a notification toggle.
    func requestPermissionIfNeeded() {
        guard !isSystemPermissionGranted else { return }

        isRequestingPermission = true

        Task {
            do {
                let center = UNUserNotificationCenter.current()
                try await center.requestAuthorization(options: [.alert, .sound, .badge])
                await refreshAuthorizationStatus()
            } catch {
                // Permission denied or error - status will reflect this
                await refreshAuthorizationStatus()
            }
            isRequestingPermission = false
        }
    }

    /// Opens the system Settings app to the notification settings for this app.
    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    /// Disables all notifications and clears preferences.
    /// Called on logout to respect privacy.
    func clearAllSettings() {
        messagesEnabled = false
        todosEnabled = false
        UserDefaults.standard.removeObject(forKey: Keys.messagesEnabled)
        UserDefaults.standard.removeObject(forKey: Keys.todosEnabled)
    }
}
