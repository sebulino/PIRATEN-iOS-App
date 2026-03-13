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

    /// Discourse auth coordinator for re-authentication
    var discourseAuthCoordinator: DiscourseAuthCoordinator?

    /// The current window for presenting auth session
    @Environment(\.window) private var window: UIWindow?

    /// Factory for creating UserProfileViewModel instances
    var userProfileViewModelFactory: ((String) -> UserProfileViewModel)?

    /// Callback when user taps "Nachricht senden" from a profile
    var onSendMessageFromProfile: ((UserProfile) -> Void)?

    /// Currently selected username for profile sheet
    @State private var selectedUsername: String?

    /// Tracks whether the initial scroll to bottom has been performed
    @State private var hasScrolledToBottom = false

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Reply composer as safeAreaInset - doesn't trigger List relayout
        // because it lives outside the List's layout hierarchy
        .safeAreaInset(edge: .bottom) {
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
        .sheet(item: Binding(
            get: { selectedUsername.map { SelectedUsername(username: $0) } },
            set: { selectedUsername = $0?.username }
        )) { selected in
            if let factory = userProfileViewModelFactory {
                UserProfileView(
                    viewModel: factory(selected.username),
                    onLoginTapped: {
                        selectedUsername = nil
                    },
                    onSendMessageTapped: { profile in
                        selectedUsername = nil
                        onSendMessageFromProfile?(profile)
                    }
                )
            }
        }
        .onAppear {
            if viewModel.loadState == .idle {
                viewModel.loadPosts()
            }
        }
    }

    // MARK: - State Views

    /// Messages list using ScrollView + LazyVStack instead of List to avoid
    /// UICollectionView cell dequeue crashes (AttributeGraph cycles).
    /// Scrolls to the last message on initial load.
    @ViewBuilder
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.posts) { post in
                        MessagePostRow(
                            post: post,
                            onUsernameTapped: { username in
                                selectedUsername = username
                            }
                        )
                        .padding(.horizontal, 16)
                        Divider()
                            .padding(.leading, 16)
                    }

                    // One-time hint to help users discover the reply button
                    if viewModel.shouldShowReplyHint && !viewModel.isComposerVisible {
                        replyHintBanner
                            .padding(.top, 16)
                    }

                    // Invisible anchor for scrolling to the bottom
                    Color.clear
                        .frame(height: 1)
                        .id("messageListBottom")
                }
            }
            .refreshable {
                viewModel.retry()
            }
            .onChange(of: viewModel.posts) { oldPosts, newPosts in
                guard !newPosts.isEmpty else { return }
                if !hasScrolledToBottom || newPosts.count > oldPosts.count {
                    hasScrolledToBottom = true
                    proxy.scrollTo("messageListBottom", anchor: .bottom)
                }
            }
            .onAppear {
                guard !viewModel.posts.isEmpty, !hasScrolledToBottom else { return }
                hasScrolledToBottom = true
                proxy.scrollTo("messageListBottom", anchor: .bottom)
            }
        }
    }

    /// A subtle banner that helps users discover the reply button on first view.
    /// Dismisses automatically when reply button is tapped or manually via X button.
    @ViewBuilder
    private var replyHintBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.piratenPrimary)
                .accessibilityHidden(true)

            Text("Tippe auf das Symbol oben, um zu antworten")
                .font(.piratenSubheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button {
                viewModel.dismissReplyHint()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("Hinweis ausblenden")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.open")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Keine Nachrichten")
                .font(.piratenHeadlineBody)
            Text("Diese Unterhaltung enthält noch keine Nachrichten.")
                .font(.piratenSubheadline)
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
            if let coordinator = discourseAuthCoordinator {
                switch coordinator.authState {
                case .idle, .failed:
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)
                    Text("Anmeldung erforderlich")
                        .font(.piratenHeadlineBody)
                    Text("Bitte melde dich an, um die Nachrichten zu sehen.")
                        .font(.piratenSubheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if case .failed(let authMessage) = coordinator.authState {
                        Text(authMessage)
                            .font(.piratenCaption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            await coordinator.authenticate(from: window)
                        }
                    } label: {
                        Label("Mit Forum verbinden", systemImage: "link")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!coordinator.isAuthAvailable)

                case .authenticating:
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Verbindung wird hergestellt...")
                        .font(.piratenSubheadline)
                        .foregroundColor(.secondary)

                case .authenticated:
                    ProgressView()
                        .onAppear {
                            viewModel.loadPosts()
                        }
                }
            } else {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                Text("Anmeldung erforderlich")
                    .font(.piratenHeadlineBody)
                Text("Bitte melde dich an, um die Nachrichten zu sehen.")
                    .font(.piratenSubheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .onChange(of: discourseAuthCoordinator?.authState) { oldState, newState in
            if newState == .authenticated {
                discourseAuthCoordinator?.reset()
                viewModel.loadPosts()
            }
        }
    }

    @ViewBuilder
    private func authenticationFailedState(message: String) -> some View {
        VStack(spacing: 16) {
            if let coordinator = discourseAuthCoordinator {
                switch coordinator.authState {
                case .idle, .failed:
                    Image(systemName: "exclamationmark.lock")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.piratenPrimary)
                        .accessibilityHidden(true)
                    Text("Sitzung abgelaufen")
                        .font(.piratenHeadlineBody)
                    Text("Die Verbindung ist abgelaufen. Bitte erneut verbinden.")
                        .font(.piratenSubheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if case .failed(let authMessage) = coordinator.authState {
                        Text(authMessage)
                            .font(.piratenCaption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            await coordinator.authenticate(from: window)
                        }
                    } label: {
                        Label("Erneut verbinden", systemImage: "link")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!coordinator.isAuthAvailable)

                case .authenticating:
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Verbindung wird hergestellt...")
                        .font(.piratenSubheadline)
                        .foregroundColor(.secondary)

                case .authenticated:
                    ProgressView()
                        .onAppear {
                            viewModel.loadPosts()
                        }
                }
            } else {
                Image(systemName: "exclamationmark.lock")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.piratenPrimary)
                    .accessibilityHidden(true)
                Text("Sitzung abgelaufen")
                    .font(.piratenHeadlineBody)
                Text(message)
                    .font(.piratenSubheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .onChange(of: discourseAuthCoordinator?.authState) { oldState, newState in
            if newState == .authenticated {
                discourseAuthCoordinator?.reset()
                viewModel.loadPosts()
            }
        }
    }

    @ViewBuilder
    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.piratenPrimary)
                .accessibilityHidden(true)
            Text("Fehler beim Laden")
                .font(.piratenHeadlineBody)
            Text(message)
                .font(.piratenSubheadline)
                .foregroundStyle(.secondary)
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

/// Row view for displaying a single message/post in the thread.
/// Shows author avatar/initials, name, timestamp, and message content.
/// Designed for private message context with a conversational appearance.
/// Links in the content are clickable.
///
/// Layout: Avatar circle | Message content (name, timestamp, body)
private struct MessagePostRow: View {
    let post: Post

    /// Callback when username is tapped
    var onUsernameTapped: ((String) -> Void)?

    /// Cached parsed content - HTML parsing via NSAttributedString is expensive
    /// (spawns WebKit parser). Computed once via .task(id:) instead of on every render.
    @State private var parsedContent: AttributedString?

    /// Extracts initials from the display name or username
    private var authorInitials: String {
        let name = post.author.displayName ?? post.author.username
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = name.first {
            return String(first).uppercased()
        }
        return "?"
    }

    /// Color for the avatar circle based on username hash
    private var avatarColor: Color {
        let colors: [Color] = [.piratenPrimary, .blue, .green, .purple, .pink, .teal]
        let hash = post.author.username.hashValue
        return colors[abs(hash) % colors.count]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar circle with initials
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.3))
                    .frame(width: 40, height: 40)
                Text(authorInitials)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(avatarColor)
            }
            .accessibilityHidden(true)

            // Message content
            VStack(alignment: .leading, spacing: 4) {
                // Author name and timestamp row
                HStack(alignment: .firstTextBaseline) {
                    Button {
                        onUsernameTapped?(post.author.username)
                    } label: {
                        Text(post.author.displayName ?? post.author.username)
                            .font(.piratenSubheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Timestamp - use relative for recent, date for older
                    Text(formatTimestamp(post.createdAt))
                        .font(.piratenCaption2)
                        .foregroundStyle(.secondary)
                }

                // Message body with clickable links
                if let content = parsedContent {
                    Text(content)
                        .font(.piratenBodyDefault)
                        .foregroundColor(.primary)
                        .tint(.blue)
                } else {
                    // Brief placeholder while HTML is being parsed
                    Text(HTMLContentParser.stripHTML(from: post.content))
                        .font(.piratenBodyDefault)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.vertical, 8)
        .task(id: post.id) {
            // Pre-parse HTML content once when the row appears.
            // NSAttributedString HTML parsing is expensive (WebKit parser),
            // so we cache the result in @State to avoid re-parsing on every render.
            parsedContent = HTMLContentParser.parseToAttributedString(post.content)
        }
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

/// Helper struct to make String identifiable for sheet presentation
private struct SelectedUsername: Identifiable {
    let username: String
    var id: String { username }
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
