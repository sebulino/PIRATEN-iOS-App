//
//  MessageThreadDetailView.swift
//  PIRATEN
//
//  Created by Claude Code on 01.02.26.
//

import SwiftUI

/// Detail view for a private message thread, displaying its posts/messages.
/// Fetches posts via DiscourseRepository and handles loading/error states.
///
/// Privacy note: This view does not log any message content or participant information.
/// All sensitive data handling follows the project's privacy-first principles.
struct MessageThreadDetailView: View {
    @ObservedObject var viewModel: MessageThreadDetailViewModel

    /// Optional callback for when user taps login button in unauthenticated state
    var onLoginTapped: (() -> Void)?

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .idle, .loading:
                if viewModel.posts.isEmpty {
                    ProgressView("Lade Nachrichten...")
                } else {
                    messagesList
                }

            case .loaded:
                if viewModel.posts.isEmpty {
                    emptyState
                } else {
                    messagesList
                }

            case .notAuthenticated:
                notAuthenticatedState

            case .authenticationFailed(let message):
                authenticationFailedState(message: message)

            case .error(let message):
                errorState(message: message)
            }
        }
        .navigationTitle(viewModel.thread.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel.loadState == .idle {
                viewModel.loadPosts()
            }
        }
    }

    // MARK: - State Views

    @ViewBuilder
    private var messagesList: some View {
        List(viewModel.posts) { post in
            MessagePostRow(post: post)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.open")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Keine Nachrichten")
                .font(.headline)
            Text("Diese Unterhaltung enthält noch keine Nachrichten.")
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
            Text("Bitte melde dich an, um die Nachrichten zu sehen.")
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

/// Row view for displaying a single message/post in the thread.
/// Shows author, content excerpt, and timestamp.
/// Designed for private message context with a more conversational appearance.
private struct MessagePostRow: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Author row
            HStack {
                Text(post.author.displayName ?? post.author.username)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                // Timestamp
                Text(post.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Message content (HTML stripped for display)
            Text(stripHTML(from: post.content))
                .font(.body)
                .lineLimit(10)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }

    /// Strips HTML tags from content for display.
    /// Note: This is a simple implementation for message content display.
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
        MessageThreadDetailView(
            viewModel: MessageThreadDetailViewModel(
                thread: MessageThread(
                    id: 1001,
                    title: "Beispiel Nachricht",
                    participants: [
                        UserSummary(id: 1, username: "test", displayName: "Test User", avatarUrl: nil)
                    ],
                    createdAt: Date(),
                    lastActivityAt: Date(),
                    postsCount: 3,
                    isRead: true,
                    lastPoster: UserSummary(id: 1, username: "test", displayName: "Test User", avatarUrl: nil)
                ),
                discourseRepository: FakeDiscourseRepository()
            )
        )
    }
}
