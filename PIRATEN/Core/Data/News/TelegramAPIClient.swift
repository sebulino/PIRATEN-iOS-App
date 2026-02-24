//
//  TelegramAPIClient.swift
//  PIRATEN
//

import Foundation

/// HTTP client for the Telegram Bot API.
/// Fetches messages from a specific chat via the `getUpdates` endpoint.
final class TelegramAPIClient: Sendable {

    // MARK: - Dependencies

    private let httpClient: HTTPClient
    private let botToken: String
    private let chatId: Int64

    // MARK: - Initialization

    init(httpClient: HTTPClient, botToken: String, chatId: Int64) {
        self.httpClient = httpClient
        self.botToken = botToken
        self.chatId = chatId
    }

    // MARK: - Public Methods

    /// Fetches messages from the configured Telegram chat.
    /// - Returns: Array of `NewsPost` entities from the bot's update queue.
    func fetchMessages() async throws -> [NewsPost] {
        var components = URLComponents(string: "https://api.telegram.org/bot\(botToken)/getUpdates")!
        components.queryItems = [
            URLQueryItem(name: "allowed_updates", value: "[\"message\"]"),
            URLQueryItem(name: "timeout", value: "0")
        ]

        guard let url = components.url else {
            throw TelegramError.invalidURL
        }

        let request = HTTPRequest.get(url)
        let response = try await httpClient.execute(request)

        guard response.isSuccess else {
            throw TelegramError.apiError(statusCode: response.statusCode)
        }

        let decoder = JSONDecoder()
        let telegramResponse: TelegramResponse<TelegramUpdate>
        do {
            telegramResponse = try decoder.decode(TelegramResponse<TelegramUpdate>.self, from: response.data)
        } catch {
            throw TelegramError.decodingError(error.localizedDescription)
        }

        guard telegramResponse.ok else {
            throw TelegramError.apiError(statusCode: 0)
        }

        return telegramResponse.result
            .compactMap { $0.message }
            .filter { $0.chat.id == chatId }
            .map { message in
                let authorName: String?
                if let user = message.from {
                    let parts = [user.firstName, user.lastName].compactMap { $0 }
                    authorName = parts.isEmpty ? nil : parts.joined(separator: " ")
                } else {
                    authorName = nil
                }

                return NewsPost(
                    id: message.messageId,
                    text: message.text,
                    date: Date(timeIntervalSince1970: TimeInterval(message.date)),
                    authorName: authorName
                )
            }
    }
}

// MARK: - Telegram Errors

enum TelegramError: Error, LocalizedError {
    case invalidURL
    case apiError(statusCode: Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Ungültige Telegram API URL"
        case .apiError(let statusCode):
            return "Telegram API Fehler (Status: \(statusCode))"
        case .decodingError(let message):
            return "Fehler beim Verarbeiten der Telegram-Daten: \(message)"
        }
    }
}

// MARK: - Telegram API DTOs (private to this file)

struct TelegramResponse<T: Decodable>: Decodable {
    let ok: Bool
    let result: [T]
}

struct TelegramUpdate: Decodable {
    let updateId: Int
    let message: TelegramMessage?

    enum CodingKeys: String, CodingKey {
        case updateId = "update_id"
        case message
    }
}

struct TelegramMessage: Decodable {
    let messageId: Int
    let date: Int
    let text: String?
    let chat: TelegramChat
    let from: TelegramUser?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case date
        case text
        case chat
        case from
    }
}

struct TelegramChat: Decodable {
    let id: Int64
}

struct TelegramUser: Decodable {
    let firstName: String
    let lastName: String?

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
    }
}
