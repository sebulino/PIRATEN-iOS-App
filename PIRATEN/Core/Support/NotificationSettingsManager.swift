//
//  NotificationSettingsManager.swift
//  PIRATEN
//
//  Created by Claude Code on 03.02.26.
//

import Foundation
import Combine
import UserNotifications
import UIKit

/// Manages per-category push notification preferences and system permissions.
/// Privacy-first: all notification categories are opt-in (default off).
/// No tracking or analytics data is collected.
///
/// Uses client-side polling of Discourse for notification detection
/// (no APNs push infrastructure required).
@MainActor
final class NotificationSettingsManager: ObservableObject {

    // MARK: - Published State

    /// Whether push notifications for new messages are enabled
    @Published var messagesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(messagesEnabled, forKey: Keys.messagesEnabled)
            if messagesEnabled { requestPermissionIfNeeded() }
        }
    }

    /// Whether push notifications for new forum topics are enabled
    @Published var forumEnabled: Bool {
        didSet {
            UserDefaults.standard.set(forumEnabled, forKey: Keys.forumEnabled)
            if forumEnabled { requestPermissionIfNeeded() }
        }
    }

    /// Whether push notifications for new or changed todos are enabled
    @Published var todosEnabled: Bool {
        didSet {
            UserDefaults.standard.set(todosEnabled, forKey: Keys.todosEnabled)
            if todosEnabled { requestPermissionIfNeeded() }
        }
    }

    /// Whether push notifications for news are enabled
    @Published var newsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(newsEnabled, forKey: Keys.newsEnabled)
            if newsEnabled { requestPermissionIfNeeded() }
        }
    }

    /// The current system authorization status
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Whether we're currently requesting permission
    @Published private(set) var isRequestingPermission = false

    // MARK: - Computed Properties

    /// Whether any notification category is enabled
    var anyNotificationsEnabled: Bool {
        messagesEnabled || forumEnabled || todosEnabled || newsEnabled
    }

    /// Whether system permission has been granted
    var isSystemPermissionGranted: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    /// Whether the user needs to grant system permission
    var needsSystemPermission: Bool {
        anyNotificationsEnabled && !isSystemPermissionGranted
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let messagesEnabled = "notification_messages_enabled"
        static let forumEnabled = "notification_forum_enabled"
        static let todosEnabled = "notification_todos_enabled"
        static let newsEnabled = "notification_news_enabled"
    }

    // MARK: - Initialization

    init() {
        // All categories default to false (opt-in for privacy)
        let defaults = UserDefaults.standard
        self.messagesEnabled = defaults.bool(forKey: Keys.messagesEnabled)
        self.forumEnabled = defaults.bool(forKey: Keys.forumEnabled)
        self.todosEnabled = defaults.bool(forKey: Keys.todosEnabled)
        self.newsEnabled = defaults.bool(forKey: Keys.newsEnabled)

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

    /// Requests system notification permission if not already granted.
    /// Only called when user explicitly enables a notification toggle.
    func requestPermissionIfNeeded() {
        guard !isSystemPermissionGranted else { return }

        isRequestingPermission = true

        Task {
            do {
                let center = UNUserNotificationCenter.current()
                _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                await refreshAuthorizationStatus()
            } catch {
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
        forumEnabled = false
        todosEnabled = false
        newsEnabled = false
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.messagesEnabled)
        defaults.removeObject(forKey: Keys.forumEnabled)
        defaults.removeObject(forKey: Keys.todosEnabled)
        defaults.removeObject(forKey: Keys.newsEnabled)
    }
}
