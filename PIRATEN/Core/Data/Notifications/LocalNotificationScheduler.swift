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
/// Category raw values serve two routing purposes:
///   • notification identifier prefixes, so delivered notifications can be
///     introspected per-source, and
///   • the `"category"` key stamped into each notification's `userInfo`, so a
///     tap can open the matching tab/sheet (see `LocalNotificationScheduler`
///     and `DeepLinkRouter.routeNotificationCategory`).
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

    /// Fixed German body string — the generic fallback shown when no
    /// item-specific `NotificationContent` is supplied (empty source list,
    /// missing title, or a deliberately-generic source like Wissen/Termine).
    /// Item-specific bodies are produced by `NotificationContentBuilder`
    /// (see THREAT_MODEL.md T-007).
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
    ///
    /// - Parameters:
    ///   - category: The source category. Its `title`/`body` are the generic
    ///     fallback text.
    ///   - content: Optional item-specific text (title + body) that overrides
    ///     the generic strings. Pass `nil` to fire the fixed generic
    ///     notification — the original behaviour.
    ///
    /// No-op gating on settings is the caller's job; the scheduler itself does
    /// not consult `NotificationSettingsManager`.
    func schedule(_ category: NotificationCategory, content: NotificationContent?) async
}

extension LocalNotificationScheduling {
    /// Convenience overload preserving the original call site
    /// `schedule(.forum)` — dispatches the generic notification.
    func schedule(_ category: NotificationCategory) async {
        await schedule(category, content: nil)
    }
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

    func schedule(_ category: NotificationCategory, content: NotificationContent?) async {
        let notification = UNMutableNotificationContent()
        // Item-specific text when the poller could identify the triggering
        // item; otherwise the fixed generic strings. The body for messages
        // names the sender + subject — kept off the lock screen by the
        // system "Vorschau: Wenn entsperrt" default (see T-007), not by code.
        notification.title = content?.title ?? category.title
        notification.body = content?.body ?? category.body
        notification.sound = .default

        // Routing payload (tap → tab/sheet): every locally-scheduled
        // notification carries its source category so a tap can open the
        // matching destination. Read by AppDelegate, applied via
        // DeepLinkRouter.routeNotificationCategory. Only the category is
        // encoded — no item id, no PII (see THREAT_MODEL.md T-007).
        notification.userInfo = ["category": category.rawValue]

        // Trigger is nil → fire immediately. A unique UUID suffix keeps
        // multiple notifications of the same category separate in the
        // delivered list rather than being coalesced.
        let request = UNNotificationRequest(
            identifier: "\(category.rawValue)-\(UUID().uuidString)",
            content: notification,
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
