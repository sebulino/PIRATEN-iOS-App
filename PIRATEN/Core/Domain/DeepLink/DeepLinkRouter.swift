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

    /// Selected tab index (0: Kajüte, 1: Forum, 2: News, 3: Wissen, 4: Termine, 5: ToDos)
    @Published var selectedTab: Int = 0

    // MARK: - Public Methods

    /// Handles a deep link, setting the pending state for navigation.
    /// The UI layer is responsible for consuming this and navigating appropriately.
    /// - Parameter deepLink: The deep link to handle
    func handle(_ deepLink: DeepLink) {
        self.pendingDeepLink = deepLink

        // Switch to the appropriate tab or trigger sheet
        switch deepLink {
        case .messageThread:
            // Messages are now presented as a sheet, handled by MainTabView's onChange
            break

        case .todoDetail:
            selectedTab = 5 // ToDos tab
        }
    }

    /// Clears the pending deep link after it has been consumed.
    func clearPendingDeepLink() {
        pendingDeepLink = nil
    }
}
