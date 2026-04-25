//
//  LikeStrategy.swift
//  PIRATEN
//
//  Created by Claude Code on 22.04.26.
//
//  Strategy abstraction for the OPEN-02 fix. The piratenpartei.de Discourse
//  instance silently drops `POST /post_actions.json` (the like is shown
//  optimistically on-device but never propagates). Three competing
//  hypotheses for why; each maps to a different concrete strategy.
//
//  Owner picks the order; the repository tries strategies in sequence and
//  caches the one that worked, so subsequent likes go straight to the
//  winning endpoint.
//

import Foundation

/// One concrete way to ask Discourse to like a post.
/// Implementations live below this comment block.
protocol LikeStrategy: Sendable {
    /// Human-readable identifier for logs and the cache key. Lower-case,
    /// kebab-case, e.g. "reactions-heart-toggle".
    var identifier: String { get }

    /// Attempts to toggle a like on `postId`. Returns `true` if the server
    /// confirmed the action (a 200/201 with non-empty success indicator).
    /// Returns `false` if the request appeared to succeed (2xx) but the
    /// like was silently dropped — the caller should then try the next
    /// strategy. Throws on transport / 4xx / 5xx errors.
    func like(postId: Int, via apiClient: DiscourseAPIClient) async throws -> Bool

    /// Counterpart for unliking.
    func unlike(postId: Int, via apiClient: DiscourseAPIClient) async throws -> Bool
}

// MARK: - Available strategies
//
// TODO(seb): Pick the strategy ORDER for `LikeStrategyRegistry.all` below.
//
// You know the production Discourse instance better than I do. Pick the
// order that matches what you believe is most likely to succeed first —
// the registry tries them in sequence and caches the winner.
//
// Three strategies are defined further down this file; you only need to
// edit the `all` array. ~5 lines of code.
//
// Trade-offs to consider:
//
// • DiscourseReactionsStrategy — POSTs to
//   `/discourse-reactions/posts/{id}/custom-reactions/heart/toggle.json`.
//   Works ONLY if the discourse-reactions plugin is installed. If it
//   isn't, returns 404. Most popular reactions plugin worldwide; near-
//   certain candidate if your instance has reaction emoji on posts.
//
// • PostActionsJSONStrategy — current behavior. POSTs JSON to
//   `/post_actions.json` with the standard `id` + `post_action_type_id=2`
//   body. This is what's shipping today and silently fails.
//
// • PostActionsFormStrategy — same endpoint, same body, but
//   `Content-Type: application/x-www-form-urlencoded` and form-encoded
//   payload. Some Discourse builds parse the JSON body but reject the
//   action; flipping to form-encoded sometimes flips the behavior.
//   Lowest-risk diff to ship if A is wrong; matches what the Discourse
//   web UI sends from the browser.
//
// Recommended starting order (auto-mode default if you don't override):
//
//   [DiscourseReactionsStrategy(),     // most likely root cause
//    PostActionsFormStrategy(),         // second most likely
//    PostActionsJSONStrategy()]         // current shipping behavior, last
//
// Only edit `LikeStrategyRegistry.all` below. Don't touch the strategy
// implementations themselves — the order alone determines the fix.

enum LikeStrategyRegistry {
    /// Order matters — strategies are tried left-to-right until one returns
    /// `true`. The winning strategy's identifier is cached in UserDefaults
    /// and tried first on subsequent likes.
    ///
    /// Current ordering picks the discourse-reactions plugin endpoint
    /// first because that's the most common cause of `/post_actions.json`
    /// silently returning 200 OK without persisting a like (OPEN-02
    /// signature). If the plugin isn't installed, that strategy returns
    /// `false` on a 404 and the chain falls through to the form-encoded
    /// `/post_actions.json` variant (matches what the Discourse web UI
    /// sends), and finally the JSON variant (current shipping behavior).
    ///
    /// To change the ordering: re-arrange the array. To narrow to a
    /// single endpoint after diagnosis: keep only that strategy.
    static let all: [LikeStrategy] = [
        DiscourseReactionsStrategy(),
        PostActionsFormStrategy(),
        PostActionsJSONStrategy()
    ]
}

// MARK: - Strategy implementations
//
// These are intentionally below the decision point so the call site
// (LikeStrategyRegistry.all) is the first thing you see when you open
// the file. Only the `all` array above needs changing.

/// Calls `/discourse-reactions/posts/{id}/custom-reactions/heart/toggle.json`.
/// The default reaction is "heart". On instances where the plugin is
/// installed, this is the only endpoint that actually persists a like
/// — the legacy `/post_actions.json` becomes a silent no-op.
struct DiscourseReactionsStrategy: LikeStrategy {
    let identifier = "discourse-reactions-heart-toggle"

    func like(postId: Int, via apiClient: DiscourseAPIClient) async throws -> Bool {
        try await apiClient.toggleReaction(postId: postId, reaction: "heart")
    }

    func unlike(postId: Int, via apiClient: DiscourseAPIClient) async throws -> Bool {
        // The reactions plugin uses a single toggle endpoint for both
        // directions — like and unlike are the same call.
        try await apiClient.toggleReaction(postId: postId, reaction: "heart")
    }
}

/// Current shipping behavior: JSON body to `/post_actions.json`.
/// Documented as failing on the production instance (OPEN-02). Kept as a
/// fallback so we don't regress if reactions is uninstalled or the
/// instance changes.
struct PostActionsJSONStrategy: LikeStrategy {
    let identifier = "post-actions-json"

    func like(postId: Int, via apiClient: DiscourseAPIClient) async throws -> Bool {
        try await apiClient.postActionLike(postId: postId, formEncoded: false)
    }

    func unlike(postId: Int, via apiClient: DiscourseAPIClient) async throws -> Bool {
        try await apiClient.postActionUnlike(postId: postId)
    }
}

/// Same endpoint as PostActionsJSONStrategy but with form-encoded body —
/// matches what the Discourse web UI sends. On Discourse builds that
/// parse JSON loosely but only honor the form-encoded path through the
/// PostActionsController, this difference fixes the silent drop.
struct PostActionsFormStrategy: LikeStrategy {
    let identifier = "post-actions-form"

    func like(postId: Int, via apiClient: DiscourseAPIClient) async throws -> Bool {
        try await apiClient.postActionLike(postId: postId, formEncoded: true)
    }

    func unlike(postId: Int, via apiClient: DiscourseAPIClient) async throws -> Bool {
        try await apiClient.postActionUnlike(postId: postId)
    }
}
