//
//  BackendPushNotificationRegistrationService.swift
//  PIRATEN
//
//  Created by Claude Code on 08.03.26.
//

import Foundation

/// Real push notification registration service that syncs device token
/// and user preferences with the PIRATEN backend.
///
/// ## Status: Scaffolded — Backend endpoint not yet confirmed
/// See Docs/OPEN_QUESTIONS.md Q-014 for the pending API details.
///
/// ## Expected API (to be confirmed with backend team)
/// - POST /api/push-subscriptions
///   Body: { "token": "<hex>", "platform": "ios", "messages": true, "todos": false, "forum": true }
/// - DELETE /api/push-subscriptions/<token>
final class BackendPushNotificationRegistrationService: PushNotificationRegistrationService {

    // MARK: - Dependencies

    private let baseURL: URL
    private let accessTokenProvider: () async throws -> String?

    // MARK: - Initialization

    /// - Parameters:
    ///   - baseURL: Base URL of the PIRATEN backend (e.g. https://meine-piraten.de)
    ///   - accessTokenProvider: Closure returning a valid access token for authentication
    init(baseURL: URL, accessTokenProvider: @escaping () async throws -> String?) {
        self.baseURL = baseURL
        self.accessTokenProvider = accessTokenProvider
    }

    // MARK: - PushNotificationRegistrationService

    func register(token: String, preferences: PushNotificationPreferences) async throws {
        guard let accessToken = try await accessTokenProvider() else {
            // Not authenticated — skip silently; will retry when user logs in
            return
        }

        // TODO: Replace path with confirmed backend endpoint (Q-014)
        let url = baseURL.appendingPathComponent("api/push-subscriptions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "token": token,
            "platform": "ios",
            "messages": preferences.messagesEnabled,
            "todos": preferences.todosEnabled,
            "forum": preferences.forumEnabled
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PushRegistrationError.registrationFailed
        }

        #if DEBUG
        print("[BackendPush] Registered token with preferences: messages=\(preferences.messagesEnabled), todos=\(preferences.todosEnabled), forum=\(preferences.forumEnabled)")
        #endif
    }

    func unregister(token: String) async throws {
        guard let accessToken = try await accessTokenProvider() else {
            return
        }

        // TODO: Replace path with confirmed backend endpoint (Q-014)
        let url = baseURL.appendingPathComponent("api/push-subscriptions/\(token)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PushRegistrationError.unregistrationFailed
        }

        #if DEBUG
        print("[BackendPush] Unregistered token")
        #endif
    }
}

// MARK: - Errors

enum PushRegistrationError: Error, LocalizedError {
    case registrationFailed
    case unregistrationFailed

    var errorDescription: String? {
        switch self {
        case .registrationFailed: return "Push-Registrierung fehlgeschlagen"
        case .unregistrationFailed: return "Push-Abmeldung fehlgeschlagen"
        }
    }
}
