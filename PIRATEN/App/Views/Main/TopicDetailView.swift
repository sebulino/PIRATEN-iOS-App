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

    /// Factory for creating UserProfileViewModel instances
    var userProfileViewModelFactory: ((String) -> UserProfileViewModel)?

    /// Callback when user taps "Nachricht senden" from a profile
    var onSendMessageFromProfile: ((UserProfile) -> Void)?

    /// Currently selected username for profile sheet
    @State private var selectedUsername: String?

    /// Focus state for reply composer text field
    @FocusState private var isComposerFocused: Bool

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
        // Reply composer as safeAreaInset - doesn't trigger ScrollView relayout
        // because it lives outside the ScrollView's layout hierarchy
        .safeAreaInset(edge: .bottom) {
            if viewModel.isAuthenticated && viewModel.isComposerVisible {
                ReplyComposerView(
                    replyText: $viewModel.replyText,
                    composerState: viewModel.composerState,
                    canSend: viewModel.canSendReply,
                    characterCount: viewModel.characterCountInfo,
                    validationError: viewModel.validationErrorMessage,
                    isFocused: $isComposerFocused,
                    replyContext: viewModel.replyingToPost.map {
                        "Antwort auf @\($0.author.displayName ?? $0.author.username) (Beitrag #\($0.postNumber))"
                    },
                    onSend: { viewModel.sendReply() },
                    onCancel: { viewModel.hideComposer() },
                    onDismissError: { viewModel.dismissComposerError() },
                    onTextChanged: { viewModel.validateReplyText() }
                )
            }
        }
        .navigationTitle(viewModel.topic.title)
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
                        onLoginTapped?()
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

    /// Posts list using ScrollView + LazyVStack instead of List to avoid
    /// UICollectionView cell dequeue crashes (AttributeGraph cycles).
    @ViewBuilder
    private var postsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.posts) { post in
                    PostRow(
                        post: post,
                        onUsernameTapped: { username in
                            selectedUsername = username
                        },
                        onReplyTapped: viewModel.isAuthenticated ? {
                            viewModel.showComposer(replyingTo: post)
                            isComposerFocused = true
                        } : nil
                    )
                    .padding(.horizontal, 16)
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
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
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
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
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
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
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Fehler beim Laden")
                .font(.headline)
            Text(message)
                .font(.subheadline)
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

/// Row view for displaying a single post in the topic.
/// Shows author, content excerpt, and metadata with expand/collapse support.
/// Links in the content are clickable.
private struct PostRow: View {
    let post: Post

    /// Callback when username is tapped
    var onUsernameTapped: ((String) -> Void)?

    /// Callback when reply button is tapped
    var onReplyTapped: (() -> Void)?

    /// Whether the post content is expanded to show full text
    @State private var isExpanded = false

    /// Cached parsed content - HTML parsing via NSAttributedString is expensive
    /// (spawns WebKit parser). Computed once via .task(id:) instead of on every render.
    @State private var parsedContent: AttributedString?

    /// Whether the content needs truncation (cached alongside parsed content)
    @State private var needsTruncation = false

    /// Line limit when collapsed (nil when expanded for full content)
    private let collapsedLineLimit = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Author and post number
            HStack {
                Button {
                    onUsernameTapped?(post.author.username)
                } label: {
                    Text(post.author.displayName ?? post.author.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("#\(post.postNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Post content with clickable links
            if let content = parsedContent {
                Text(content)
                    .font(.body)
                    .lineLimit(isExpanded ? nil : collapsedLineLimit)
                    .foregroundColor(.primary)
                    .tint(.blue)
            } else {
                // Brief placeholder while HTML is being parsed
                Text(HTMLContentParser.stripHTML(from: post.content))
                    .font(.body)
                    .lineLimit(collapsedLineLimit)
                    .foregroundColor(.primary)
            }

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
                    .foregroundStyle(.secondary)

                Spacer()

                // Reply count
                if post.replyCount > 0 {
                    Label("\(post.replyCount)", systemImage: "arrowshape.turn.up.left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(post.replyCount) Antworten")
                }

                // Like count
                if post.likeCount > 0 {
                    Label("\(post.likeCount)", systemImage: "heart")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(post.likeCount) Likes")
                }

                // Reply button
                if let onReplyTapped = onReplyTapped {
                    Button {
                        onReplyTapped()
                    } label: {
                        Label("Antworten", systemImage: "arrowshape.turn.up.left")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
        .task(id: post.id) {
            // Pre-parse HTML content once when the row appears.
            // NSAttributedString HTML parsing is expensive (WebKit parser),
            // so we cache the result in @State to avoid re-parsing on every render.
            let content = HTMLContentParser.parseToAttributedString(post.content)
            let plainText = HTMLContentParser.stripHTML(from: post.content)
            parsedContent = content
            needsTruncation = plainText.count > 300
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
