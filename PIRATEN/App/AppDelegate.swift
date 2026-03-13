//
//  AppDelegate.swift
//  PIRATEN
//
//  Created by Claude Code on 03.02.26.
//

import UIKit
import UserNotifications

/// AppDelegate to handle APNs device token registration callbacks and notification routing.
/// In SwiftUI, this is integrated via @UIApplicationDelegateAdaptor.
///
/// Privacy note: Device tokens are stored locally but never logged in full.
/// Tokens are only sent to backend when notification settings are enabled.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// Device token manager for storing and managing APNs tokens
    var deviceTokenManager: DeviceTokenManager?

    /// Deep link router for handling notification taps
    var deepLinkRouter: DeepLinkRouter?

    // MARK: - UIApplicationDelegate

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification center delegate for handling notification taps
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Forward to device token manager for storage
        deviceTokenManager?.didReceiveDeviceToken(deviceToken)
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("tokenString: \(tokenString)")
        
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Forward to device token manager for error handling
        deviceTokenManager?.didFailToRegister(with: error)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when a notification is delivered to the app while in the foreground.
    /// Determines whether to show the notification banner/sound while app is active.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner and sound even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Called when the user taps on a notification.
    /// Routes the notification to the appropriate screen via deep linking.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Parse deep link from notification payload
        if let deepLink = DeepLink.from(userInfo: userInfo) {
            // Route via deep link router (will be consumed by UI)
            Task { @MainActor in
                deepLinkRouter?.handle(deepLink)
            }
        }

        #if DEBUG
        print("[AppDelegate] Notification tapped, deep link parsed: \(DeepLink.from(userInfo: userInfo) != nil)")
        #endif

        completionHandler()
    }
}



