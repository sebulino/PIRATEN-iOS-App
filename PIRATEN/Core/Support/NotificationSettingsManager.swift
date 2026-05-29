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
///
/// Categories default to **ON (opt-out)** so a fresh install gets useful
/// notifications without configuration, matching the Android app (Q-068).
/// This is bounded by iOS itself: no notification is delivered until the user
/// grants the system permission prompt, which is requested in-context the first
/// time the authenticated main screen appears. Members can switch any category
/// off in Profile, and that explicit choice always wins (see `init`).
///
/// Still privacy-first: no tracking or analytics data is collected, and
/// detection uses client-side polling of Discourse (no APNs push
/// infrastructure required).
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

    /// Whether push notifications for Knowledge-Hub updates are enabled.
    /// Fires when the PIRATEN-Kanon repo publishes a new or changed topic.
    /// Added in FR-PROF-002 (six categories, default on / opt-out — Q-068).
    @Published var knowledgeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(knowledgeEnabled, forKey: Keys.knowledgeEnabled)
            if knowledgeEnabled { requestPermissionIfNeeded() }
        }
    }

    /// Whether push notifications for new calendar events are enabled.
    /// Fires when piragitator.de publishes a new event that has not been seen locally.
    /// Added in FR-PROF-002 (six categories, default on / opt-out — Q-068).
    @Published var eventsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(eventsEnabled, forKey: Keys.eventsEnabled)
            if eventsEnabled { requestPermissionIfNeeded() }
        }
    }

    /// The current system authorization status
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Whether we're currently requesting permission
    @Published private(set) var isRequestingPermission = false

    // MARK: - Computed Properties

    /// Whether any notification category is enabled
    var anyNotificationsEnabled: Bool {
        messagesEnabled || forumEnabled || todosEnabled || newsEnabled || knowledgeEnabled || eventsEnabled
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
        static let knowledgeEnabled = "notification_knowledge_enabled"
        static let eventsEnabled = "notification_events_enabled"
    }

    // MARK: - Initialization

    init() {
        let defaults = UserDefaults.standard
        // Opt-out by default (Q-068): seed every category to `true` in the
        // registration domain so a fresh install gets notifications without
        // configuration, matching the Android app. `register(defaults:)` is the
        // LOWEST-priority domain, so an explicit user choice (turning a category
        // off, persisted via the `didSet` below) always wins and survives
        // relaunches. Must run before any `bool(forKey:)` read.
        defaults.register(defaults: [
            Keys.messagesEnabled: true,
            Keys.forumEnabled: true,
            Keys.todosEnabled: true,
            Keys.newsEnabled: true,
            Keys.knowledgeEnabled: true,
            Keys.eventsEnabled: true
        ])
        self.messagesEnabled = defaults.bool(forKey: Keys.messagesEnabled)
        self.forumEnabled = defaults.bool(forKey: Keys.forumEnabled)
        self.todosEnabled = defaults.bool(forKey: Keys.todosEnabled)
        self.newsEnabled = defaults.bool(forKey: Keys.newsEnabled)
        self.knowledgeEnabled = defaults.bool(forKey: Keys.knowledgeEnabled)
        self.eventsEnabled = defaults.bool(forKey: Keys.eventsEnabled)

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
    ///
    /// Must be kept in sync with the `@Published var *Enabled` properties
    /// above. If you add a new category, add it here too — otherwise the
    /// next user of the device sees the previous user's notification
    /// preference. Security audit M-2 / LogoutOrchestrator depends on this.
    ///
    /// Opt-out interaction (Q-068): setting the in-memory flags to `false`
    /// stops any further notifications for the *current* session (the poller
    /// and background coordinator both gate on `anyNotificationsEnabled`).
    /// Removing the explicit keys means a freshly-constructed manager on the
    /// next launch/login falls back to the registered opt-out default (all
    /// on) — i.e. the next user starts from the same uniform default, never
    /// from the previous user's specific choices. That still satisfies M-2:
    /// no preference *leaks* across users.
    func clearAllSettings() {
        messagesEnabled = false
        forumEnabled = false
        todosEnabled = false
        newsEnabled = false
        knowledgeEnabled = false
        eventsEnabled = false
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.messagesEnabled)
        defaults.removeObject(forKey: Keys.forumEnabled)
        defaults.removeObject(forKey: Keys.todosEnabled)
        defaults.removeObject(forKey: Keys.newsEnabled)
        defaults.removeObject(forKey: Keys.knowledgeEnabled)
        defaults.removeObject(forKey: Keys.eventsEnabled)
    }
}
