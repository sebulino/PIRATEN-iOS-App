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

/// Manages notification permissions and the single opt-in toggle.
/// Privacy-first: notifications are opt-in (default off).
/// No tracking or analytics data is collected.
///
/// Uses client-side polling of Discourse for notification detection
/// (no APNs push infrastructure required).
@MainActor
final class NotificationSettingsManager: ObservableObject {

    // MARK: - Published State

    /// Whether push notifications are enabled by the user (opt-in, default off)
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
            if notificationsEnabled {
                requestPermissionIfNeeded()
            }
        }
    }

    /// Whether message badges are shown in the tab bar
    @Published var messagesEnabled: Bool {
        didSet { UserDefaults.standard.set(messagesEnabled, forKey: Keys.messagesEnabled) }
    }

    /// Whether forum badges are shown in the tab bar
    @Published var forumEnabled: Bool {
        didSet { UserDefaults.standard.set(forumEnabled, forKey: Keys.forumEnabled) }
    }

    /// Whether todo badges are shown in the tab bar
    @Published var todosEnabled: Bool {
        didSet { UserDefaults.standard.set(todosEnabled, forKey: Keys.todosEnabled) }
    }

    /// Whether news badges are shown in the tab bar
    @Published var newsEnabled: Bool {
        didSet { UserDefaults.standard.set(newsEnabled, forKey: Keys.newsEnabled) }
    }

    /// The current system authorization status
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Whether we're currently requesting permission
    @Published private(set) var isRequestingPermission = false

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let notificationsEnabled = "notification_enabled"
        static let messagesEnabled = "notification_messages_enabled"
        static let forumEnabled = "notification_forum_enabled"
        static let todosEnabled = "notification_todos_enabled"
        static let newsEnabled = "notification_news_enabled"
    }

    // MARK: - Initialization

    init() {
        // Load saved preferences (push notifications default off, badges default on)
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: Keys.notificationsEnabled)

        // Badge toggles default to true (opt-out)
        let defaults = UserDefaults.standard
        self.messagesEnabled = defaults.object(forKey: Keys.messagesEnabled) as? Bool ?? true
        self.forumEnabled = defaults.object(forKey: Keys.forumEnabled) as? Bool ?? true
        self.todosEnabled = defaults.object(forKey: Keys.todosEnabled) as? Bool ?? true
        self.newsEnabled = defaults.object(forKey: Keys.newsEnabled) as? Bool ?? true

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

    /// Whether system permission has been granted
    var isSystemPermissionGranted: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    /// Whether the user needs to grant system permission
    var needsSystemPermission: Bool {
        notificationsEnabled && !isSystemPermissionGranted
    }

    /// Requests system notification permission if not already granted.
    /// Only called when user explicitly enables the notification toggle.
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

    /// Disables notifications and clears preferences.
    /// Called on logout to respect privacy.
    func clearAllSettings() {
        notificationsEnabled = false
        messagesEnabled = true
        forumEnabled = true
        todosEnabled = true
        newsEnabled = true
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.notificationsEnabled)
        defaults.removeObject(forKey: Keys.messagesEnabled)
        defaults.removeObject(forKey: Keys.forumEnabled)
        defaults.removeObject(forKey: Keys.todosEnabled)
        defaults.removeObject(forKey: Keys.newsEnabled)
    }
}
