//
//  DeepLinkRouter.swift
//  PIRATEN
//
//  Created by Claude Code on 08.02.26.
//

import Foundation
import Combine

/// Manages deep link navigation state across the app.
/// Handles routing from notifications to specific screens.
@MainActor
final class DeepLinkRouter: ObservableObject {

    // MARK: - Published State

    /// The pending deep link waiting to be handled
    @Published var pendingDeepLink: DeepLink?

    /// Selected tab index. The TabView has no tag 2 — News and Nachrichten
    /// are presented as sheets, not tabs:
    ///   0: Kajüte · 1: Forum · 3: Wissen · 4: Termine · 5: ToDos
    @Published var selectedTab: Int = 0

    /// One-shot request to present the Nachrichten (private messages) sheet,
    /// raised by a notification tap. MainTabView observes this, opens the
    /// sheet, and resets it to `false`.
    @Published var pendingMessagesSheet: Bool = false

    /// One-shot request to present the News sheet, raised by a notification
    /// tap. MainTabView observes this, opens the sheet, and resets it.
    @Published var pendingNewsSheet: Bool = false

    // MARK: - Public Methods

    /// Handles a deep link, setting the pending state for navigation.
    /// The UI layer is responsible for consuming this and navigating appropriately.
    /// - Parameter deepLink: The deep link to handle
    func handle(_ deepLink: DeepLink) {
        self.pendingDeepLink = deepLink

        // Switch to the appropriate tab or trigger sheet
        switch deepLink {
        case .messageThread:
            // Messages are presented as a sheet, handled by MainTabView's onChange
            break

        case .todoDetail:
            selectedTab = 5 // ToDos tab

        case .forumTopic:
            selectedTab = 1 // Forum tab
        }
    }

    /// Clears the pending deep link after it has been consumed.
    func clearPendingDeepLink() {
        pendingDeepLink = nil
    }

    /// Routes a tapped notification to its in-app destination, identified by
    /// the notification's source category.
    ///
    /// The category is passed as a plain `String` (`NotificationCategory.rawValue`)
    /// rather than the enum itself, so this Domain-layer router does not depend
    /// on the Data-layer scheduler. The raw values are asserted against the
    /// `NotificationCategory` enum in DeepLinkRouterTests so the two cannot
    /// drift apart silently.
    ///
    /// Tab-backed sources switch `selectedTab`; the two sheet-backed sources
    /// (Nachrichten, News) raise a one-shot flag MainTabView observes. Unknown
    /// values are ignored — a tap then just brings the app forward.
    func routeNotificationCategory(_ rawValue: String) {
        switch rawValue {
        case "forum":     selectedTab = 1
        case "knowledge": selectedTab = 3
        case "events":    selectedTab = 4
        case "todos":     selectedTab = 5
        case "messages":  pendingMessagesSheet = true
        case "news":      pendingNewsSheet = true
        default:          break
        }
    }
}
