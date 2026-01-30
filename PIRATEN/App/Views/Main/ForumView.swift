//
//  ForumView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct ForumView: View {
    @ObservedObject var viewModel: ForumViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.topics.isEmpty {
                    ProgressView("Lade Themen...")
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Erneut versuchen") {
                            viewModel.loadTopics()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    topicsList
                }
            }
            .navigationTitle("Forum")
            .onAppear {
                if viewModel.topics.isEmpty {
                    viewModel.loadTopics()
                }
            }
        }
    }

    @ViewBuilder
    private var topicsList: some View {
        List(viewModel.topics) { topic in
            TopicRow(topic: topic)
        }
        .refreshable {
            viewModel.refresh()
        }
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
