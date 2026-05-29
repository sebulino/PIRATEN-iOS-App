//
//  AppDelegate.swift
//  PIRATEN
//
//  Created by Claude Code on 03.02.26.
//

import BackgroundTasks
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

        // Register and schedule background polling
        BackgroundTaskScheduler.shared.register()
        BackgroundTaskScheduler.shared.scheduleAppRefresh()

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
        let itemDeepLink = DeepLink.from(userInfo: userInfo)
        let category = userInfo["category"] as? String

        Task { @MainActor in
            if let itemDeepLink {
                // Item-level: open a specific message thread / todo / forum
                // topic when the payload carries one.
                deepLinkRouter?.handle(itemDeepLink)
            } else if let category {
                // Category-level: open the source's tab or sheet. This is the
                // path every locally-scheduled notification takes today — the
                // scheduler stamps the category into userInfo, with no item id.
                deepLinkRouter?.routeNotificationCategory(category)
            }
        }

        #if DEBUG
        print("[AppDelegate] Notification tapped — itemDeepLink: \(itemDeepLink != nil), category: \(category ?? "nil")")
        #endif

        completionHandler()
    }
}
