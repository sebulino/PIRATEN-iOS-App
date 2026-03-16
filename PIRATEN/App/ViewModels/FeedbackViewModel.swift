//
//  FeedbackViewModel.swift
//  PIRATEN
//

import Foundation
import Combine

enum FeedbackType {
    case positive
    case negative

    var title: String {
        switch self {
        case .positive: return "App-Feedback: was mir gefällt"
        case .negative: return "App-Feedback: was ich nicht mag"
        }
    }
}

enum FeedbackSendState: Equatable {
    case idle
    case sending
    case sent
    case failed(String)
}

@MainActor
final class FeedbackViewModel: ObservableObject, Identifiable {
    let id = UUID()
    let feedbackType: FeedbackType

    @Published var bodyText = ""
    @Published private(set) var state: FeedbackSendState = .idle

    private let discourseRepository: DiscourseRepository
    private let recipient = "sebulino"

    init(type: FeedbackType, discourseRepository: DiscourseRepository) {
        self.feedbackType = type
        self.discourseRepository = discourseRepository
    }

    func send() async {
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state = .sending
        do {
            _ = try await discourseRepository.createPrivateMessage(
                recipient: recipient,
                title: feedbackType.title,
                content: trimmed
            )
            state = .sent
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
