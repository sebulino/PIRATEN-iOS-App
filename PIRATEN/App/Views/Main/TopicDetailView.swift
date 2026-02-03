//
//  TopicDetailView.swift
//  PIRATEN
//
//  Created by Claude Code on 31.01.26.
//

import SwiftUI

/// Detail view for a single forum topic, displaying its posts.
/// Fetches posts via DiscourseRepository and handles loading/error states.
struct TopicDetailView: View {
    @ObservedObject var viewModel: TopicDetailViewModel

    /// Optional callback for when user taps login button in unauthenticated state
    var onLoginTapped: (() -> Void)?

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .idle, .loading:
                if viewModel.posts.isEmpty {
                    ProgressView("Lade Beiträge...")
                } else {
                    postsList
                }

            case .loaded:
                if viewModel.posts.isEmpty {
                    emptyState
                } else {
                    postsList
                }

            case .notAuthenticated:
                notAuthenticatedState

            case .authenticationFailed(let message):
                authenticationFailedState(message: message)

            case .error(let message):
                errorState(message: message)
            }
        }
        .navigationTitle(viewModel.topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel.loadState == .idle {
                viewModel.loadPosts()
            }
        }
    }

    // MARK: - State Views

    @ViewBuilder
    private var postsList: some View {
        List(viewModel.posts) { post in
            PostRow(post: post)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Keine Beiträge")
                .font(.headline)
            Text("Dieses Thema enthält noch keine Beiträge.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Aktualisieren") {
                viewModel.retry()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    @ViewBuilder
    private var notAuthenticatedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            Text("Anmeldung erforderlich")
                .font(.headline)
            Text("Bitte melde dich an, um die Beiträge zu sehen.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Anmelden") {
                onLoginTapped?()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @ViewBuilder
    private func authenticationFailedState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.lock")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Sitzung abgelaufen")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Erneut anmelden") {
                onLoginTapped?()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @ViewBuilder
    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Fehler beim Laden")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") {
                viewModel.retry()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

/// Row view for displaying a single post in the topic.
/// Shows author, content excerpt, and metadata with expand/collapse support.
private struct PostRow: View {
    let post: Post

    /// Whether the post content is expanded to show full text
    @State private var isExpanded = false

    /// Line limit when collapsed (nil when expanded for full content)
    private let collapsedLineLimit = 6

    /// Stripped content for display
    private var strippedContent: String {
        stripHTML(from: post.content)
    }

    /// Whether the content needs truncation (rough heuristic based on character count)
    private var needsTruncation: Bool {
        // Approximate: if content is longer than ~300 chars, it likely exceeds 6 lines
        strippedContent.count > 300
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Author and post number
            HStack {
                Text(post.author.displayName ?? post.author.username)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text("#\(post.postNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Post content (HTML stripped for display)
            Text(strippedContent)
                .font(.body)
                .lineLimit(isExpanded ? nil : collapsedLineLimit)
                .foregroundColor(.primary)

            // Expand/collapse button (only shown if content is long enough)
            if needsTruncation {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Weniger anzeigen" : "Mehr anzeigen")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }

            // Metadata row
            HStack {
                // Time
                Text(post.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                // Reply count
                if post.replyCount > 0 {
                    Label("\(post.replyCount)", systemImage: "arrowshape.turn.up.left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Like count
                if post.likeCount > 0 {
                    Label("\(post.likeCount)", systemImage: "heart")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Strips HTML tags from content for display.
    /// Note: This is a simple implementation for excerpts.
    /// For full HTML rendering, consider using AttributedString or a WebView.
    private func stripHTML(from htmlString: String) -> String {
        // Remove HTML tags using regex
        let stripped = htmlString
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return stripped
    }
}

#Preview {
    NavigationStack {
        TopicDetailView(
            viewModel: TopicDetailViewModel(
                topic: Topic(
                    id: 1,
                    title: "Beispiel Thema",
                    createdBy: UserSummary(id: 1, username: "test", displayName: "Test User", avatarUrl: nil),
                    createdAt: Date(),
                    postsCount: 5,
                    viewCount: 100,
                    likeCount: 10,
                    categoryId: 1,
                    isVisible: true,
                    isClosed: false,
                    isArchived: false
                ),
                discourseRepository: FakeDiscourseRepository()
            )
        )
    }
}
