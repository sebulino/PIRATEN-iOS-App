//
//  NewsView.swift
//  PIRATEN
//

import SwiftUI

struct NewsView: View {
    @ObservedObject var viewModel: NewsViewModel

    /// Callback when user taps the profile toolbar button
    var onProfileTapped: (() -> Void)?

    /// Callback when user taps the notifications toolbar button
    var onNotificationsTapped: (() -> Void)?

    /// Whether to show a badge on the notification bell
    var notificationsBadge: Bool = false

    /// Callback when user taps the home button to navigate to Kajüte
    var onHomeTapped: (() -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadState {
                case .idle, .loading:
                    ProgressView("Lade News...")

                case .loaded:
                    if viewModel.posts.isEmpty {
                        emptyState
                    } else {
                        loadedContent
                    }

                case .error(let message):
                    errorState(message: message)
                }
            }
            .navigationTitle("News")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onHomeTapped?()
                    } label: {
                        Image(systemName: "house")
                    }
                    .accessibilityLabel("Kajüte")
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        onNotificationsTapped?()
                    } label: {
                        Image(systemName: notificationsBadge ? "bell.badge" : "bell")
                    }
                    .accessibilityLabel("Benachrichtigungen")

                    Button {
                        onProfileTapped?()
                    } label: {
                        Image(systemName: "person.circle")
                    }
                    .accessibilityLabel("Profil")
                }
            }
            .onAppear {
                if viewModel.loadState == .idle {
                    viewModel.loadNews()
                }
            }
        }
    }

    // MARK: - Loaded Content

    @ViewBuilder
    private var loadedContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(viewModel.posts) { post in
                    NewsPostRow(post: post)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    // MARK: - State Views

    private var emptyState: some View {
        ContentUnavailableView(
            "Keine News",
            systemImage: "newspaper",
            description: Text("Aktuell sind keine Neuigkeiten verfügbar.")
        )
    }

    @ViewBuilder
    private func errorState(message: String) -> some View {
        ContentUnavailableView {
            Label("Fehler", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Erneut versuchen") {
                viewModel.loadNews()
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - News Post Row

private struct NewsPostRow: View {
    let post: NewsPost

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let authorName = post.authorName {
                    Text(authorName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(post.date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let text = post.text {
                Text(text)
                    .font(.body)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

#Preview {
    NewsView(
        viewModel: NewsViewModel(newsRepository: FakeNewsRepository())
    )
}
