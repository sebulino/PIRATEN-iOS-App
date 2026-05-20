//
//  LocalNotificationScheduler.swift
//  PIRATEN
//
//  Created by Claude Code on 22.04.26.
//
//  Single dispatch helper for local notifications. Shared between the
//  foreground `.onChange` path in MainTabView and the headless
//  BackgroundRefreshCoordinator invoked from BGAppRefreshTask.
//
//  Before this type existed, notification dispatch lived only in a SwiftUI
//  view's `.onChange` observers — which do not fire while the app is in
//  the background. See OPEN-12 / FR-NOTIF-004.
//

import Foundation
import UserNotifications

/// The six notification categories tracked by the app.
/// Maps 1:1 to the six toggles in `NotificationSettingsManager`.
/// Category raw values are used as notification identifier prefixes so
/// delivered notifications can be introspected per-source.
enum NotificationCategory: String, CaseIterable, Sendable {
    case forum
    case messages
    case todos
    case news
    case knowledge
    case events

    /// Fixed German title string shown in the notification banner.
    var title: String {
        switch self {
        case .forum:     return "Neuer Forumsbeitrag"
        case .messages:  return "Neue Nachricht"
        case .todos:     return "Neue Aufgabe"
        case .news:      return "Neue Neuigkeit"
        case .knowledge: return "Neuer Wissensbeitrag"
        case .events:    return "Neuer Termin"
        }
    }

    /// Fixed German body string shown in the notification banner.
    /// Privacy note: bodies are generic — we never include the actual
    /// topic/message content (see THREAT_MODEL.md T-007).
    var body: String {
        switch self {
        case .forum:     return "Es gibt neue Beiträge im Forum."
        case .messages:  return "Du hast neue private Nachrichten."
        case .todos:     return "Es gibt neue oder geänderte Aufgaben."
        case .news:      return "Es gibt neue Neuigkeiten."
        case .knowledge: return "Das Wissens-Kompendium wurde aktualisiert."
        case .events:    return "Im Kalender gibt es einen neuen Termin."
        }
    }
}

/// Protocol so tests can substitute an in-memory fake scheduler.
protocol LocalNotificationScheduling: Sendable {
    /// Dispatch a local notification for the given category.
    /// No-op if the caller has not verified the per-category setting is enabled —
    /// the scheduler itself does not gate on settings.
    func schedule(_ category: NotificationCategory) async
}

/// Production scheduler that submits to `UNUserNotificationCenter`.
/// Works both in-view (foreground) and headless (background).
struct LocalNotificationScheduler: LocalNotificationScheduling {

    /// `nonisolated` so the default-value expression
    /// `scheduler: LocalNotificationScheduling = LocalNotificationScheduler()`
    /// on `BackgroundRefreshCoordinator.init` is valid under
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. The struct holds
    /// no mutable state.
    nonisolated init() {}

    func schedule(_ category: NotificationCategory) async {
        let content = UNMutableNotificationContent()
        content.title = category.title
        content.body = category.body
        content.sound = .default

        // Trigger is nil → fire immediately. A unique UUID suffix keeps
        // multiple notifications of the same category separate in the
        // delivered list rather than being coalesced.
        let request = UNNotificationRequest(
            identifier: "\(category.rawValue)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            #if DEBUG
            print("[LocalNotificationScheduler] Failed to add request for \(category.rawValue): \(error)")
            #endif
        }
    }
}
