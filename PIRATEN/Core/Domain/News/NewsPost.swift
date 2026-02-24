//
//  NewsPost.swift
//  PIRATEN
//

import Foundation

/// A news post from the Telegram bot news channel.
struct NewsPost: Identifiable, Codable, Equatable {
    /// Telegram message_id
    let id: Int

    /// Message text (may be nil for media-only messages)
    let text: String?

    /// When the message was sent
    let date: Date

    /// Author name from Telegram (first_name + last_name)
    let authorName: String?
}
