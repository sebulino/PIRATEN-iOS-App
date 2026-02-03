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
    @FocusState private var isComposerFocused: Bool

    /// Optional callback for when user taps login button in unauthenticated state
    var onLoginTapped: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            Group {
                switch viewModel.loadState {
                case .idle, .loading:
                    if viewModel.posts.isEmpty {
                        ProgressView("Lade Nachrichten...")
                    } else {
                        messagesListWithReply
                    }

                case .loaded:
                    if viewModel.posts.isEmpty {
                        emptyState
                    } else {
                        messagesListWithReply
                    }

                case .notAuthenticated:
                    notAuthenticatedState

                case .authenticationFailed(let message):
                    authenticationFailedState(message: message)

                case .error(let message):
                    errorState(message: message)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Reply composer at bottom (only shown when authenticated and composer is visible)
            if viewModel.isAuthenticated && viewModel.isComposerVisible {
                ReplyComposerView(
                    replyText: $viewModel.replyText,
                    composerState: viewModel.composerState,
                    canSend: viewModel.canSendReply,
                    characterCount: viewModel.characterCountInfo,
                    validationError: viewModel.validationErrorMessage,
                    isFocused: $isComposerFocused,
                    onSend: { viewModel.sendReply() },
                    onCancel: { viewModel.hideComposer() },
                    onDismissError: { viewModel.dismissComposerError() },
                    onTextChanged: { viewModel.validateReplyText() }
                )
            }
        }
        .navigationTitle(viewModel.thread.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isAuthenticated && !viewModel.isComposerVisible {
                    Button {
                        viewModel.showComposer()
                        isComposerFocused = true
                    } label: {
                        Label("Antworten", systemImage: "square.and.pencil")
                    }
                }
            }
        }
        .onAppear {
            if viewModel.loadState == .idle {
                viewModel.loadPosts()
            }
        }
    }

    // MARK: - State Views

    @ViewBuilder
    private var messagesListWithReply: some View {
        List {
            ForEach(viewModel.posts) { post in
                MessagePostRow(post: post)
            }

            // Show inline reply prompt at the bottom of the list when composer is not visible
            if viewModel.isAuthenticated && !viewModel.isComposerVisible {
                replyPromptRow
            }
        }
        .refreshable {
            viewModel.retry()
        }
    }

    @ViewBuilder
    private var replyPromptRow: some View {
        Button {
            viewModel.showComposer()
            isComposerFocused = true
        } label: {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundColor(.accentColor)
                Text("Antworten...")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
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

// MARK: - Reply Composer View

/// A composer view for writing and sending a reply to a PM thread.
/// Supports plain text only with clear send/cancel actions.
/// Includes character count display and input validation.
///
/// Privacy note: Message content is never logged.
private struct ReplyComposerView: View {
    @Binding var replyText: String
    let composerState: ReplyComposerState
    let canSend: Bool
    let characterCount: (current: Int, max: Int, isOverLimit: Bool)
    let validationError: String?
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onCancel: () -> Void
    let onDismissError: () -> Void
    let onTextChanged: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Error banner (shown when sending failed)
            if case .failed(let message) = composerState {
                errorBanner(message: message)
            }

            // Validation error (shown when input is invalid)
            if let validationError = validationError, composerState != .sending {
                validationBanner(message: validationError)
            }

            // Success banner (shown briefly after successful send)
            if composerState == .sent {
                successBanner
            }

            // Character count row (shown when approaching limit)
            if characterCount.current > characterCount.max / 2 || characterCount.isOverLimit {
                characterCountRow
            }

            // Composer input area
            HStack(alignment: .bottom, spacing: 12) {
                // Cancel button
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .disabled(composerState == .sending)

                // Text input
                TextField("Nachricht schreiben...", text: $replyText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .focused(isFocused)
                    .disabled(composerState == .sending)
                    .onChange(of: replyText) { _, _ in
                        onTextChanged()
                    }
                    .onSubmit {
                        if canSend {
                            onSend()
                        }
                    }

                // Send button
                Button {
                    onSend()
                } label: {
                    Group {
                        if composerState == .sending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                    }
                    .font(.title2)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    @ViewBuilder
    private var characterCountRow: some View {
        HStack {
            Spacer()
            Text("\(characterCount.current)/\(characterCount.max)")
                .font(.caption2)
                .foregroundColor(characterCount.isOverLimit ? .red : .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text(message)
                .font(.caption)
                .foregroundColor(.white)
            Spacer()
            Button {
                onDismissError()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.red)
    }

    @ViewBuilder
    private func validationBanner(message: String) -> some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
    }

    @ViewBuilder
    private var successBanner: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
            Text("Nachricht gesendet")
                .font(.caption)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.green)
    }
}

/// Row view for displaying a single message/post in the thread.
/// Shows author avatar/initials, name, timestamp, and message content.
/// Designed for private message context with a conversational appearance.
/// Links in the content are clickable.
///
/// Layout: Avatar circle | Message content (name, timestamp, body)
private struct MessagePostRow: View {
    let post: Post

    /// Extracts initials from the display name or username
    private var authorInitials: String {
        let name = post.author.displayName ?? post.author.username
        let words = name.split(separator: " ")
        if words.count >= 2 {
            // First letter of first two words
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = name.first {
            return String(first).uppercased()
        }
        return "?"
    }

    /// Color for the avatar circle based on username hash
    private var avatarColor: Color {
        let colors: [Color] = [.orange, .blue, .green, .purple, .pink, .teal]
        let hash = post.author.username.hashValue
        return colors[abs(hash) % colors.count]
    }

    /// Parsed content with clickable links
    private var parsedContent: AttributedString {
        HTMLContentParser.parseToAttributedString(post.content)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar circle with initials
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text(authorInitials)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(avatarColor)
            }

            // Message content
            VStack(alignment: .leading, spacing: 4) {
                // Author name and timestamp row
                HStack(alignment: .firstTextBaseline) {
                    Text(post.author.displayName ?? post.author.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    // Timestamp - use relative for recent, date for older
                    Text(formatTimestamp(post.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Message body with clickable links
                Text(parsedContent)
                    .font(.body)
                    .foregroundColor(.primary)
                    .tint(.blue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 8)
    }

    /// Formats timestamp: relative for recent messages, date for older ones
    private func formatTimestamp(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date, to: now)

        if let days = components.day, days < 7 {
            // Within a week: use relative format
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: date, relativeTo: now)
        } else {
            // Older than a week: show date
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
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
