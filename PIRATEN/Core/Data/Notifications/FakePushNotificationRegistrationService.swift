//
//  FakePushNotificationRegistrationService.swift
//  PIRATEN
//
//  Created by Claude Code on 08.03.26.
//

import Foundation

/// Fake push notification registration service for development and testing.
/// Logs what would be sent; does not call any real backend.
final class FakePushNotificationRegistrationService: PushNotificationRegistrationService {

    func register(token: String, preferences: PushNotificationPreferences) async throws {
        #if DEBUG
        let tokenPrefix = String(token.prefix(8))
        print("""
            [FakePush] register(token: \(tokenPrefix)..., preferences: \
            messages=\(preferences.messagesEnabled), \
            todos=\(preferences.todosEnabled), \
            forum=\(preferences.forumEnabled), \
            news=\(preferences.newsEnabled))
            """)
        #endif
    }

    func unregister(token: String) async throws {
        #if DEBUG
        let tokenPrefix = String(token.prefix(8))
        print("[FakePush] unregister(token: \(tokenPrefix)...)")
        #endif
    }
}
