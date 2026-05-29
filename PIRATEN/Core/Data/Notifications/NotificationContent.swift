//
//  NotificationContent.swift
//  PIRATEN
//
//  Created by Claude Code on 29.05.26.
//
//  Optional, item-specific override for a local notification's visible text.
//  When a poller can identify the concrete item that triggered a notification
//  (the newest forum topic, the newest private message, …) it builds one of
//  these and hands it to the scheduler. When it cannot — empty list, missing
//  title, or a source we deliberately keep generic (Wissen, Termine) — it
//  passes `nil` and the scheduler falls back to the fixed strings on
//  `NotificationCategory`.
//
//  See THREAT_MODEL.md T-007 for the privacy reasoning behind which sources
//  may name their item and how message contents stay hidden on the lock
//  screen.
//

import Foundation

/// The visible text for a single local notification.
///
/// Built by `NotificationContentBuilder` from the newest item of a source.
/// All copy is German UI text (ADR-0008); the surrounding code stays English.
struct NotificationContent: Sendable, Equatable {
    /// Bold banner title. Usually the category's fixed title
    /// (e.g. "Neuer Forumsbeitrag").
    let title: String

    /// Body line naming the concrete item, e.g.
    /// `Neuer Beitrag im Thema »Mitgliederversammlung 2026«`.
    let body: String

    /// Whether this body contains content that should not be readable on a
    /// locked screen (currently only private-message sender + subject).
    ///
    /// iOS has no per-notification `setPublicVersion` equivalent (unlike
    /// Android). We rely on the system-wide *"Vorschau zeigen: Wenn
    /// entsperrt"* default, which redacts the body on the lock screen and
    /// reveals it only after Face/Touch ID. This flag therefore does **not**
    /// change scheduling behaviour — it documents intent and lets tests
    /// assert that the messages builder marks its output sensitive.
    let isLockscreenSensitive: Bool
}
