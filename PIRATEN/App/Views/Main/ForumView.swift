//
//  ForumView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct ForumView: View {
    @ObservedObject var viewModel: ForumViewModel

    /// Optional callback for when user taps login button in unauthenticated state
    var onLoginTapped: (() -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadState {
                case .idle, .loading:
                    if viewModel.topics.isEmpty {
                        ProgressView("Lade Themen...")
                    } else {
                        // Show existing topics while refreshing
                        topicsList
                    }

                case .loaded:
                    if viewModel.topics.isEmpty {
                        emptyState
                    } else {
                        topicsList
                    }

                case .notAuthenticated:
                    notAuthenticatedState

                case .authenticationFailed(let message):
                    authenticationFailedState(message: message)

                case .error(let message):
                    errorState(message: message)
                }
            }
            .navigationTitle("Forum")
            .onAppear {
                if viewModel.loadState == .idle {
                    viewModel.loadTopics()
                }
            }
        }
    }

    // MARK: - State Views

    @ViewBuilder
    private var topicsList: some View {
        List(viewModel.topics) { topic in
            TopicRow(topic: topic)
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Keine Themen")
                .font(.headline)
            Text("Es wurden noch keine Themen gepostet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Aktualisieren") {
                viewModel.refresh()
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
            Text("Bitte melde dich an, um das Forum zu sehen.")
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
                viewModel.loadTopics()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

/// Row view for displaying a single topic in the list.
/// Shows topic title, author, and metadata.
private struct TopicRow: View {
    let topic: Topic

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(topic.title)
                .font(.headline)
                .lineLimit(2)

            HStack {
                // Author name
                Text(topic.createdBy.displayName ?? topic.createdBy.username)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                // Post count
                Label("\(topic.postsCount)", systemImage: "bubble.left")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // View count
                Label("\(topic.viewCount)", systemImage: "eye")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Time ago
            Text(topic.createdAt, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    // Preview with fake data - uses FakeDiscourseRepository
    ForumView(viewModel: ForumViewModel(discourseRepository: FakeDiscourseRepository()))
}
