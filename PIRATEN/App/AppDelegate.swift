//
//  AppDelegate.swift
//  PIRATEN
//
//  Created by Claude Code on 03.02.26.
//

import UIKit
import UserNotifications

/// AppDelegate to handle APNs device token registration callbacks.
/// In SwiftUI, this is integrated via @UIApplicationDelegateAdaptor.
///
/// Privacy note: Device tokens are stored locally but never logged in full.
/// Tokens are only sent to backend when notification settings are enabled.
final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Device token manager for storing and managing APNs tokens
    var deviceTokenManager: DeviceTokenManager?

    // MARK: - UIApplicationDelegate

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Standard app launch - no tracking, no analytics
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Forward to device token manager for storage
        deviceTokenManager?.didReceiveDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Forward to device token manager for error handling
        deviceTokenManager?.didFailToRegister(with: error)
    }
}
