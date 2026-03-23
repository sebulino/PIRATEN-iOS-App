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

    /// Whether notifications are enabled by the user
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
            if notificationsEnabled {
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
        static let notificationsEnabled = "notification_enabled"
    }

    // MARK: - Initialization

    init() {
        // Load saved preference (default to false for privacy)
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: Keys.notificationsEnabled)

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
        UserDefaults.standard.removeObject(forKey: Keys.notificationsEnabled)
    }
}
