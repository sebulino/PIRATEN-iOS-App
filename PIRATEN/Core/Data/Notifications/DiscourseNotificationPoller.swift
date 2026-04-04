//
//  DiscourseNotificationPoller.swift
//  PIRATEN
//
//  Created by Claude Code on 23.03.26.
//

import Foundation
import Combine
import UserNotifications

/// Polls the Discourse instance for notification count changes and creates
/// local notifications when new notifications are detected.
///
/// This follows the same approach as the official Discourse mobile app
/// for self-hosted instances: poll `/notifications/totals.json`, compare
/// against last-known counts, and schedule local notifications on increase.
///
/// Privacy note: No notification content is fetched — only aggregate counts.
@MainActor
final class DiscourseNotificationPoller: ObservableObject {

    // MARK: - Dependencies

    private let httpClient: HTTPClient
    private let baseURL: URL
    private let notificationSettingsManager: NotificationSettingsManager

    // MARK: - State

    /// Last known total notification count, persisted across launches
    @Published private(set) var lastKnownTotal: Int

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let lastKnownTotal = "discourse_notification_last_total"
    }

    // MARK: - Initialization

    /// - Parameters:
    ///   - httpClient: An authenticated HTTP client (should be DiscourseHTTPClient)
    ///   - baseURL: Base URL of the Discourse instance
    ///   - notificationSettingsManager: Manager for per-category notification preferences
    init(httpClient: HTTPClient, baseURL: URL, notificationSettingsManager: NotificationSettingsManager) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.notificationSettingsManager = notificationSettingsManager
        self.lastKnownTotal = UserDefaults.standard.integer(forKey: Keys.lastKnownTotal)
    }

    // MARK: - Polling

    /// Polls Discourse for notification totals and creates a local notification
    /// if the count has increased since the last poll.
    ///
    /// - Returns: The current total notification count, or nil on failure
    @discardableResult
    func poll() async -> Int? {
        do {
            let totals = try await fetchNotificationTotals()
            let newTotal = totals.unreadNotifications

            lastKnownTotal = newTotal
            UserDefaults.standard.set(newTotal, forKey: Keys.lastKnownTotal)

            // Only update app badge if user has enabled at least one notification category
            if notificationSettingsManager.anyNotificationsEnabled {
                try? await UNUserNotificationCenter.current().setBadgeCount(newTotal)
            } else {
                try? await UNUserNotificationCenter.current().setBadgeCount(0)
            }

            #if DEBUG
            print("[NotificationPoller] Polled: total=\(newTotal), previous=\(lastKnownTotal)")
            #endif

            return newTotal
        } catch {
            #if DEBUG
            print("[NotificationPoller] Poll failed: \(error)")
            #endif
            return nil
        }
    }

    /// Resets stored counts. Called on logout.
    func reset() {
        lastKnownTotal = 0
        UserDefaults.standard.removeObject(forKey: Keys.lastKnownTotal)
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }

    // MARK: - Private

    private func fetchNotificationTotals() async throws -> NotificationTotals {
        let url = baseURL.appendingPathComponent("notifications/totals.json")
        let request = HTTPRequest(url: url, method: .get, headers: [:], body: nil)
        let response = try await httpClient.execute(request)
        guard response.isSuccess else {
            throw HTTPError.serverError(statusCode: response.statusCode, message: "Notification poll failed")
        }
        return try JSONDecoder().decode(NotificationTotals.self, from: response.data)
    }

}

// MARK: - DTO

/// Response from Discourse `/notifications/totals.json` endpoint.
/// Only the fields we need for polling.
struct NotificationTotals: Decodable, Sendable {
    let unreadNotifications: Int

    enum CodingKeys: String, CodingKey {
        case unreadNotifications = "unread_notifications"
    }
}
