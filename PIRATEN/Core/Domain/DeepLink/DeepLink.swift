//
//  DeepLink.swift
//  PIRATEN
//
//  Created by Claude Code on 08.02.26.
//

import Foundation

/// Represents a deep link destination in the app.
/// Used for notification routing and programmatic navigation.
enum DeepLink: Equatable, Hashable {
    /// Navigate to a specific private message thread
    case messageThread(topicId: Int)

    /// Navigate to a specific todo detail
    case todoDetail(todoId: String)

    // MARK: - Parsing from Notification Payload

    /// Parses a deep link from a notification userInfo dictionary.
    /// Returns nil if the payload doesn't contain valid deep link data.
    ///
    /// Expected payload formats:
    /// - Message: {"deepLink": "message", "topicId": 12345}
    /// - Todo: {"deepLink": "todo", "todoId": "abc-123"}
    static func from(userInfo: [AnyHashable: Any]) -> DeepLink? {
        guard let linkType = userInfo["deepLink"] as? String else {
            return nil
        }

        switch linkType {
        case "message":
            guard let topicId = userInfo["topicId"] as? Int else {
                return nil
            }
            return .messageThread(topicId: topicId)

        case "todo":
            guard let todoId = userInfo["todoId"] as? String else {
                return nil
            }
            return .todoDetail(todoId: todoId)

        default:
            return nil
        }
    }
}
