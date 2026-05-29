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

    /// Navigate to a specific forum topic
    case forumTopic(topicId: Int)

    // MARK: - Parsing from Notification Payload

    /// Parses a deep link from a notification userInfo dictionary.
    /// Returns nil if the payload doesn't contain valid deep link data.
    ///
    /// Expected payload formats:
    /// - Message: {"deepLink": "message", "topicId": 12345}
    /// - Todo:    {"deepLink": "todo",    "todoId": "abc-123"}
    /// - Forum:   {"deepLink": "forum",   "topicId": 12345}
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

        case "forum":
            guard let topicId = userInfo["topicId"] as? Int else {
                return nil
            }
            return .forumTopic(topicId: topicId)

        default:
            return nil
        }
    }

    // MARK: - Encoding to Notification Payload

    /// The notification `userInfo` representation of this deep link — the exact
    /// inverse of `from(userInfo:)`. The scheduler stamps this onto a local
    /// notification so a tap can be routed back to the same destination.
    ///
    /// `from(userInfo: deepLink.userInfo) == deepLink` for every case (covered
    /// by a round-trip test). Only an item identifier is encoded — no titles,
    /// bodies, or other content (see THREAT_MODEL.md T-007).
    var userInfo: [AnyHashable: Any] {
        switch self {
        case .messageThread(let topicId):
            return ["deepLink": "message", "topicId": topicId]
        case .todoDetail(let todoId):
            return ["deepLink": "todo", "todoId": todoId]
        case .forumTopic(let topicId):
            return ["deepLink": "forum", "topicId": topicId]
        }
    }
}
