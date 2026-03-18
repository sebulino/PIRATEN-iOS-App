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
///
/// Syncs device token + preferences to the backend via
/// PushNotificationRegistrationService whenever either changes.
@MainActor
final class NotificationSettingsManager: ObservableObject {

    // MARK: - Dependencies

    private let deviceTokenManager: DeviceTokenManager
    private let registrationService: PushNotificationRegistrationService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published State

    /// Whether message notifications are enabled by the user
    @Published var messagesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(messagesEnabled, forKey: Keys.messagesEnabled)
            if messagesEnabled {
                requestPermissionIfNeeded()
            }
            syncRegistration()
        }
    }

    /// Whether todo notifications are enabled by the user
    @Published var todosEnabled: Bool {
        didSet {
            UserDefaults.standard.set(todosEnabled, forKey: Keys.todosEnabled)
            if todosEnabled {
                requestPermissionIfNeeded()
            }
            syncRegistration()
        }
    }

    /// Whether forum post notifications are enabled by the user
    @Published var forumEnabled: Bool {
        didSet {
            UserDefaults.standard.set(forumEnabled, forKey: Keys.forumEnabled)
            if forumEnabled {
                requestPermissionIfNeeded()
            }
            syncRegistration()
        }
    }

    /// Whether news notifications are enabled by the user
    @Published var newsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(newsEnabled, forKey: Keys.newsEnabled)
            if newsEnabled {
                requestPermissionIfNeeded()
            }
            syncRegistration()
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
        static let forumEnabled = "notification_forum_enabled"
        static let newsEnabled = "notification_news_enabled"
    }

    // MARK: - Initialization

    init(
        deviceTokenManager: DeviceTokenManager,
        registrationService: PushNotificationRegistrationService
    ) {
        self.deviceTokenManager = deviceTokenManager
        self.registrationService = registrationService

        // Load saved preferences (default to false for privacy)
        self.messagesEnabled = UserDefaults.standard.bool(forKey: Keys.messagesEnabled)
        self.todosEnabled = UserDefaults.standard.bool(forKey: Keys.todosEnabled)
        self.forumEnabled = UserDefaults.standard.bool(forKey: Keys.forumEnabled)
        self.newsEnabled = UserDefaults.standard.bool(forKey: Keys.newsEnabled)

        // Check current authorization status
        Task {
            await refreshAuthorizationStatus()
        }

        // Observe device token changes — sync when a new token arrives
        deviceTokenManager.$deviceToken
            .dropFirst() // skip the initial value (already synced on startup if needed)
            .sink { [weak self] token in
                guard token != nil else { return }
                self?.syncRegistration()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Refreshes the current authorization status from the system.
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
    }

    /// Whether any notification type is enabled
    var hasAnyNotificationsEnabled: Bool {
        messagesEnabled || todosEnabled || forumEnabled || newsEnabled
    }

    /// Whether system permission has been granted
    var isSystemPermissionGranted: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    /// Whether the user needs to grant system permission
    var needsSystemPermission: Bool {
        hasAnyNotificationsEnabled && !isSystemPermissionGranted
    }

    #if DEBUG
    /// Device token hex string for testing via Apple Push Notification Console.
    /// Only available in debug builds.
    var debugDeviceTokenString: String? {
        deviceTokenManager.deviceTokenString
    }
    #endif

    /// Requests system notification permission if not already granted.
    /// Only called when user explicitly enables a notification toggle.
    func requestPermissionIfNeeded() {
        guard !isSystemPermissionGranted else {
            // Permission already granted - register for remote notifications
            deviceTokenManager.registerForRemoteNotifications()
            return
        }

        isRequestingPermission = true

        Task {
            do {
                let center = UNUserNotificationCenter.current()
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                await refreshAuthorizationStatus()

                // If permission was granted, register for remote notifications
                if granted {
                    deviceTokenManager.registerForRemoteNotifications()
                }
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
        // Unregister from backend before clearing token
        if let token = deviceTokenManager.deviceTokenString {
            Task {
                try? await registrationService.unregister(token: token)
            }
        }

        messagesEnabled = false
        todosEnabled = false
        forumEnabled = false
        newsEnabled = false
        UserDefaults.standard.removeObject(forKey: Keys.messagesEnabled)
        UserDefaults.standard.removeObject(forKey: Keys.todosEnabled)
        UserDefaults.standard.removeObject(forKey: Keys.forumEnabled)
        UserDefaults.standard.removeObject(forKey: Keys.newsEnabled)

        // Clear device token on logout
        deviceTokenManager.clearDeviceToken()
    }

    // MARK: - Private Helpers

    /// Syncs the current token and preferences to the backend.
    /// Called whenever a toggle changes or a new device token is received.
    /// Failures are logged but not surfaced to the user.
    private func syncRegistration() {
        guard let token = deviceTokenManager.deviceTokenString else {
            // No token yet — will sync once token is received via Combine observer
            return
        }

        let preferences = PushNotificationPreferences(
            messagesEnabled: messagesEnabled,
            todosEnabled: todosEnabled,
            forumEnabled: forumEnabled,
            newsEnabled: newsEnabled
        )

        Task {
            do {
                if hasAnyNotificationsEnabled {
                    try await registrationService.register(token: token, preferences: preferences)
                } else {
                    try await registrationService.unregister(token: token)
                }
            } catch {
                // Sync failures are non-fatal — user's local preferences remain correct
                #if DEBUG
                print("[NotificationSettingsManager] Sync failed: \(error)")
                #endif
            }
        }
    }
}
