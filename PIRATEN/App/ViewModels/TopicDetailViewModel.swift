//
//  TopicDetailViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import Foundation
import Combine

/// Represents the current state of the topic detail view.
enum TopicDetailLoadState: Equatable {
    /// Initial state, no data loaded yet
    case idle

    /// Currently loading posts
    case loading

    /// Posts loaded successfully
    case loaded

    /// User is not authenticated - should show login prompt
    case notAuthenticated

    /// Authentication failed (session expired) - should show re-login prompt
    case authenticationFailed(message: String)

    /// Loading failed with an error message
    case error(message: String)
}

/// ViewModel for the topic detail screen.
/// Coordinates between the TopicDetailView and the DiscourseRepository.
@MainActor
final class TopicDetailViewModel: ObservableObject {

    // MARK: - Published State

    /// The topic being viewed
    @Published private(set) var topic: Topic

    /// The list of posts in this topic
    @Published private(set) var posts: [Post] = []

    /// The current load state
    @Published private(set) var loadState: TopicDetailLoadState = .idle

    /// Error message from a failed like/unlike action (nil when no error)
    @Published private(set) var likeErrorMessage: String?

    // MARK: - Reply Composer State

    /// Whether the reply composer is currently shown
    @Published var isComposerVisible: Bool = false

    /// The text content of the reply being composed
    @Published var replyText: String = ""

    /// The current state of the reply composer
    @Published private(set) var composerState: ReplyComposerState = .idle

    /// Validation error message for the composer (nil if valid)
    @Published private(set) var validationErrorMessage: String?

    /// The post being replied to (nil for general topic reply)
    @Published private(set) var replyingToPost: Post?

    /// Whether the user is authenticated (derived from load state)
    var isAuthenticated: Bool {
        switch loadState {
        case .notAuthenticated, .authenticationFailed:
            return false
        default:
            return true
        }
    }

    /// Whether the send button should be enabled
    var canSendReply: Bool {
        let validation = safetyService.validate(content: replyText)
        return validation.isValid
            && composerState != .sending
            && safetyService.canSend()
    }

    /// Current character count info for display
    var characterCountInfo: (current: Int, max: Int, isOverLimit: Bool) {
        safetyService.characterCount(for: replyText)
    }

    // MARK: - Dependencies

    private let discourseRepository: DiscourseRepository
    private let safetyService: MessageSafetyService

    // MARK: - Initialization

    /// Creates a TopicDetailViewModel with the given topic and repository.
    /// - Parameters:
    ///   - topic: The topic to display details for
    ///   - discourseRepository: The repository to fetch post data from
    ///   - safetyService: The safety service for rate limiting and validation (optional, creates new instance if nil)
    init(
        topic: Topic,
        discourseRepository: DiscourseRepository,
        safetyService: MessageSafetyService? = nil
    ) {
        self.topic = topic
        self.discourseRepository = discourseRepository
        self.safetyService = safetyService ?? MessageSafetyService()
    }

    // MARK: - Public Methods

    /// Loads posts for the current topic and marks it as read.
    func loadPosts() {
        loadState = .loading

        Task {
            do {
                let fetchedPosts = try await discourseRepository.fetchPosts(forTopicId: topic.id)
                self.posts = fetchedPosts
                self.loadState = .loaded

                // Mark topic as read in background (don't block the UI)
                if !topic.isRead, let highestPostNumber = fetchedPosts.last?.postNumber {
                    self.markAsRead(highestPostNumber: highestPostNumber)
                }
            } catch let error as DiscourseRepositoryError {
                handleError(error)
            } catch {
                self.loadState = .error(message: "Ein unbekannter Fehler ist aufgetreten")
            }
        }
    }

    /// Marks the topic as read locally and notifies Discourse.
    private func markAsRead(highestPostNumber: Int) {
        // Update local model immediately so the list view reflects the change
        topic = Topic(
            id: topic.id,
            title: topic.title,
            createdBy: topic.createdBy,
            createdAt: topic.createdAt,
            postsCount: topic.postsCount,
            viewCount: topic.viewCount,
            likeCount: topic.likeCount,
            categoryId: topic.categoryId,
            isVisible: topic.isVisible,
            isClosed: topic.isClosed,
            isArchived: topic.isArchived,
            isRead: true
        )

        // Notify Discourse in the background — failure is non-fatal
        Task {
            try? await discourseRepository.markTopicAsRead(
                topicId: topic.id,
                highestPostNumber: highestPostNumber
            )
        }
    }

    /// Retries loading posts after an error.
    func retry() {
        loadPosts()
    }

    // MARK: - Reply Composer Methods

    /// Shows the reply composer.
    /// - Parameter post: The post to reply to (nil for general topic reply)
    func showComposer(replyingTo post: Post? = nil) {
        replyingToPost = post
        isComposerVisible = true
        composerState = .idle
    }

    /// Hides the reply composer and clears the text.
    func hideComposer() {
        isComposerVisible = false
        replyText = ""
        composerState = .idle
        validationErrorMessage = nil
        replyingToPost = nil
    }

    /// Validates the current reply text and updates the validation error message.
    /// Call this when the user changes the text to provide real-time feedback.
    func validateReplyText() {
        let validation = safetyService.validate(content: replyText)
        validationErrorMessage = validation.errorMessage
    }

    /// Sends the reply via the Discourse API.
    /// Uses DiscourseRepository.replyToForumPost to POST the message.
    /// Respects rate limiting via MessageSafetyService.
    func sendReply() {
        // Validate before sending
        let validation = safetyService.validate(content: replyText)
        guard validation.isValid else {
            validationErrorMessage = validation.errorMessage
            return
        }

        // Check rate limit
        guard safetyService.canSend() else {
            composerState = .failed(message: "Bitte warte einen Moment vor dem nächsten Senden.")
            return
        }

        let contentToSend = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        composerState = .sending
        safetyService.willStartSend()

        Task {
            do {
                // Send the reply via API
                try await discourseRepository.replyToForumPost(
                    topicId: topic.id,
                    content: contentToSend,
                    replyToPostNumber: replyingToPost?.postNumber
                )

                // Mark as sent successfully
                safetyService.didCompleteSend(success: true)
                composerState = .sent
                replyText = ""
                validationErrorMessage = nil

                // After a brief moment, hide composer and reload posts
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                isComposerVisible = false
                composerState = .idle
                replyingToPost = nil

                // Reload posts to show the new reply
                loadPosts()
            } catch let error as DiscourseRepositoryError {
                safetyService.didCompleteSend(success: false)
                handleComposerError(error)
            } catch {
                safetyService.didCompleteSend(success: false)
                composerState = .failed(message: "Antwort konnte nicht gesendet werden")
            }
        }
    }

    /// Toggles the like state of a post.
    /// Immediately updates the UI, then fires the API call in the background.
    /// On API failure the local state is kept (next refresh syncs with server).
    func toggleLike(for post: Post) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }

        let wasLiked = post.likedByCurrentUser
        posts[index] = Post(
            id: post.id,
            topicId: post.topicId,
            postNumber: post.postNumber,
            author: post.author,
            replyToPostNumber: post.replyToPostNumber,
            createdAt: post.createdAt,
            content: post.content,
            replyCount: post.replyCount,
            likeCount: wasLiked ? max(0, post.likeCount - 1) : post.likeCount + 1,
            likedByCurrentUser: !wasLiked,
            isRead: post.isRead
        )
        likeErrorMessage = nil

        Task {
            do {
                if wasLiked {
                    try await discourseRepository.unlikePost(id: post.id)
                } else {
                    try await discourseRepository.likePost(id: post.id)
                }
            } catch {
                likeErrorMessage = "Änderung konnte nicht gespeichert werden"
            }
        }
    }

    /// Dismisses any error state in the composer.
    func dismissComposerError() {
        if case .failed = composerState {
            composerState = .idle
        }
    }

    // MARK: - Private Helpers

    private func handleError(_ error: DiscourseRepositoryError) {
        switch error {
        case .notAuthenticated:
            loadState = .notAuthenticated
        case .authenticationFailed(let message):
            loadState = .authenticationFailed(message: message)
        case .loadFailed(let message):
            loadState = .error(message: message)
        }
    }

    private func handleComposerError(_ error: DiscourseRepositoryError) {
        switch error {
        case .notAuthenticated:
            loadState = .notAuthenticated
            composerState = .idle
        case .authenticationFailed(let message):
            loadState = .authenticationFailed(message: message)
            composerState = .idle
        case .loadFailed(let message):
            composerState = .failed(message: message)
        }
    }
}
