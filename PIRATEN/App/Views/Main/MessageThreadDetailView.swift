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

    /// Callback when user taps the archive button
    var onArchive: (() -> Void)?

    /// Environment dismiss action for popping back after archive
    @Environment(\.dismiss) private var dismiss

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
        .navigationTitle(HTMLContentParser.replaceEmojiShortcodes(in: viewModel.thread.title))
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
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.posts) { post in
                        MessagePostRow(
                            post: post,
                            isFromCurrentUser: post.author.username == viewModel.currentUsername,
                            onUsernameTapped: { username in
                                selectedUsername = username
                            }
                        )
                        .padding(.horizontal, 12)
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
            .overlay(alignment: .bottomLeading) {
                if let onArchive, viewModel.isAuthenticated, !viewModel.isComposerVisible {
                    Button {
                        onArchive()
                        dismiss()
                    } label: {
                        Image(systemName: "archivebox")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(Color.piratenPrimary)
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .accessibilityLabel("Archivieren")
                    .padding(.leading, 16)
                    .padding(.bottom, 16)
                }
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

/// Row view for displaying a single message as a chat bubble.
/// Current user's messages: right-aligned with orange outline.
/// Other users' messages: left-aligned with warm grey outline, avatar on left.
private struct MessagePostRow: View {
    let post: Post
    let isFromCurrentUser: Bool

    /// Callback when username is tapped
    var onUsernameTapped: ((String) -> Void)?

    /// Cached parsed content - HTML parsing via NSAttributedString is expensive
    /// (spawns WebKit parser). Computed once via .task(id:) instead of on every render.
    @State private var parsedContent: AttributedString?

    /// Cached avatar image — loaded via .task(id:) to avoid AsyncImage's
    /// URLSession saturation in long LazyVStack lists (fails after ~33 items).
    @State private var avatarImage: UIImage?

    /// Inline images extracted from the post HTML, loaded manually to avoid
    /// AsyncImage saturation in long threads.
    @State private var inlineImages: [(url: URL, image: UIImage)] = []
    @State private var imageURLs: [URL] = []

    private let bubbleCornerRadius: CGFloat = 16
    private var bubbleColor: Color { isFromCurrentUser ? .orange : Color(.systemGray4) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 48)
            } else {
                // Other user's avatar
                avatarView
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                // Author name (only for other users)
                if !isFromCurrentUser {
                    Button {
                        onUsernameTapped?(post.author.username)
                    } label: {
                        Text(post.author.displayName ?? post.author.username)
                            .font(.piratenCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 12)
                }

                // Bubble
                VStack(alignment: .leading, spacing: 6) {
                    // Message body
                    SelectableTextView(
                        attributedString: parsedContent,
                        plainText: parsedContent == nil ? HTMLContentParser.stripHTML(from: post.content) : nil
                    )
                    .fixedSize(horizontal: false, vertical: true)

                    // Inline images
                    ForEach(inlineImages, id: \.url.absoluteString) { item in
                        Image(uiImage: item.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Timestamp inside the bubble
                    Text(formatTimestamp(post.createdAt))
                        .font(.piratenCaption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: bubbleCornerRadius)
                        .stroke(bubbleColor, lineWidth: 1.5)
                )
            }

            if isFromCurrentUser {
                // Current user's avatar
                avatarView
            } else {
                Spacer(minLength: 48)
            }
        }
        .padding(.vertical, 2)
        .task(id: post.id) {
            parsedContent = HTMLContentParser.parseToAttributedString(post.content)

            let urls = HTMLContentParser.extractImageURLs(from: post.content)
            imageURLs = urls
            for url in urls {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        inlineImages.append((url: url, image: image))
                    }
                } catch {
                    // Skip failed images
                }
            }

            if avatarImage == nil, let url = post.author.avatarUrl {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        avatarImage = image
                    }
                } catch {
                    // Silently fail — placeholder icon remains visible
                }
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let avatarImage {
            Image(uiImage: avatarImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .accessibilityHidden(true)
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
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
