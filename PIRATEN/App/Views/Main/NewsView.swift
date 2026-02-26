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

    /// Callback when user taps the messages button to open Nachrichten
    var onMessagesTapped: (() -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadState {
                case .idle, .loading:
                    ProgressView("Lade News...")

                case .loaded:
                    if viewModel.items.isEmpty {
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
                    HStack(spacing: 2) {
                        PiratenIconButton(
                            systemName: "house",
                            accessibilityLabel: "Kajüte"
                        ) {
                            onHomeTapped?()
                        }
                        PiratenIconButton(
                            systemName: "envelope",
                            accessibilityLabel: "Nachrichten"
                        ) {
                            onMessagesTapped?()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 2) {
                        PiratenIconButton(
                            systemName: notificationsBadge ? "bell.badge" : "bell",
                            badge: notificationsBadge,
                            accessibilityLabel: "Benachrichtigungen"
                        ) {
                            onNotificationsTapped?()
                        }

                        PiratenIconButton(
                            systemName: "person.circle",
                            accessibilityLabel: "Profil"
                        ) {
                            onProfileTapped?()
                        }
                    }
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
            if let errorMessage = viewModel.errorMessage {
                errorBanner(message: errorMessage)
            }

            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(viewModel.items) { item in
                    NavigationLink(destination: NewsDetailView(item: item)) {
                        NewsCardView(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    // MARK: - Error Banner

    @ViewBuilder
    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Retry") {
                viewModel.refresh()
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
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

#Preview {
    NewsView(
        viewModel: NewsViewModel(
            newsRepository: FakeNewsRepository(),
            cache: NewsCacheStore()
        )
    )
}
