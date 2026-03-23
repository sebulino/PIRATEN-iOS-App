//
//  AppDelegate.swift
//  PIRATEN
//
//  Created by Claude Code on 03.02.26.
//

import UIKit
import UserNotifications

/// AppDelegate to handle notification routing.
/// In SwiftUI, this is integrated via @UIApplicationDelegateAdaptor.
///
/// Handles local notification presentation and tap routing via deep links.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

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
