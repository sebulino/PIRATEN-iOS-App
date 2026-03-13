//
//  KnowledgeView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct KnowledgeView: View {
    @ObservedObject var viewModel: KnowledgeViewModel

    /// Factory for creating KnowledgeTopicDetailViewModel
    var topicDetailViewModelFactory: ((KnowledgeTopic) -> KnowledgeTopicDetailViewModel)?

    /// Callback when user taps the profile toolbar button
    var onProfileTapped: (() -> Void)?

    /// Callback when user taps the notifications toolbar button
    var onNotificationsTapped: (() -> Void)?

    /// Whether to show a badge on the notification bell
    var notificationsBadge: Bool = false

    /// Callback when user taps the messages button to open Nachrichten
    var onMessagesTapped: (() -> Void)?

    /// Callback when user taps the news button to open News
    var onNewsTapped: (() -> Void)?

    private let categoryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadState {
                case .idle, .loading:
                    ProgressView("Lade Wissen...")

                case .loaded:
                    if let results = viewModel.searchResults {
                        searchResultsList(results)
                    } else if viewModel.categories.isEmpty {
                        emptyState
                    } else {
                        loadedContent
                    }

                case .error(let message):
                    errorState(message: message)
                }
            }
            .piratenStyledBackground()
            .navigationTitle("Wissen")
            .searchable(text: $viewModel.searchQuery, prompt: "Themen durchsuchen")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 2) {
                        PiratenIconButton(
                            systemName: "envelope",
                            accessibilityLabel: "Nachrichten"
                        ) {
                            onMessagesTapped?()
                        }
                        PiratenIconButton(
                            systemName: "newspaper",
                            accessibilityLabel: "News"
                        ) {
                            onNewsTapped?()
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
                    viewModel.loadIndex()
                }
            }
        }
    }

    // MARK: - Loaded Content

    @ViewBuilder
    private var loadedContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                // Featured section
                if !viewModel.featuredTopics.isEmpty {
                    featuredSection
                }

                // In-progress section
                if !viewModel.inProgressTopics.isEmpty {
                    inProgressSection
                }

                // Categories grid
                categoriesSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable {
            viewModel.loadIndex(forceRefresh: true)
        }
    }

    // MARK: - Featured Section

    @ViewBuilder
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Empfohlen")
                .font(.title2)
                .fontWeight(.bold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.featuredTopics) { topic in
                        topicNavigationLink(topic) {
                            FeaturedTopicCard(
                                topic: topic,
                                progress: viewModel.progress(for: topic.id)
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - In-Progress Section

    @ViewBuilder
    private var inProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weiterlesen")
                .font(.title2)
                .fontWeight(.bold)

            ForEach(viewModel.inProgressTopics) { topic in
                topicNavigationLink(topic) {
                    TopicListRow(
                        topic: topic,
                        progress: viewModel.progress(for: topic.id)
                    )
                }
                Divider()
            }
        }
    }

    // MARK: - Categories Section

    @ViewBuilder
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kategorien")
                .font(.title2)
                .fontWeight(.bold)

            LazyVGrid(columns: categoryColumns, spacing: 12) {
                ForEach(viewModel.categories) { category in
                    NavigationLink {
                        CategoryDetailView(
                            category: category,
                            topics: viewModel.topicsForCategory(category.id),
                            progressStore: viewModel,
                            topicDetailViewModelFactory: topicDetailViewModelFactory
                        )
                    } label: {
                        CategoryCard(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private func searchResultsList(_ results: [KnowledgeTopic]) -> some View {
        if results.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Keine Ergebnisse")
                    .font(.headline)
                Text("Für \"\(viewModel.searchQuery)\" wurden keine Themen gefunden.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(results) { topic in
                        topicNavigationLink(topic) {
                            TopicListRow(
                                topic: topic,
                                progress: viewModel.progress(for: topic.id)
                            )
                        }
                        Divider()
                            .padding(.leading, 16)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - State Views

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Keine Inhalte")
                .font(.headline)
            Text("Es sind noch keine Wissensartikel verfügbar.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Aktualisieren") {
                viewModel.loadIndex(forceRefresh: true)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    @ViewBuilder
    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.piratenPrimary)
            Text("Fehler beim Laden")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") {
                viewModel.loadIndex(forceRefresh: true)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Helpers

    @ViewBuilder
    private func topicNavigationLink<Content: View>(
        _ topic: KnowledgeTopic,
        @ViewBuilder label: () -> Content
    ) -> some View {
        if let factory = topicDetailViewModelFactory {
            NavigationLink {
                KnowledgeTopicDetailView(viewModel: factory(topic))
            } label: {
                label()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            label()
        }
    }
}

// MARK: - Progress Provider Protocol

/// Allows CategoryDetailView to query progress without coupling to KnowledgeViewModel directly.
protocol TopicProgressProvider {
    func progress(for topicId: String) -> TopicProgress?
}

extension KnowledgeViewModel: TopicProgressProvider {}

// MARK: - Featured Topic Card

private struct FeaturedTopicCard: View {
    let topic: KnowledgeTopic
    let progress: TopicProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(topic.level)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundColor(.accentColor)
                    .clipShape(Capsule())

                Spacer()

                statusIcon
            }

            Text(topic.title)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(topic.summary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            HStack {
                Label("\(topic.readingMinutes) Min.", systemImage: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(width: 200, height: 160)
        .background(Color.piratenSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var statusIcon: some View {
        if let progress {
            switch progress.status {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                    .accessibilityLabel("Abgeschlossen")
            case .started:
                Image(systemName: "book.fill")
                    .foregroundColor(.accentColor)
                    .font(.caption)
                    .accessibilityLabel("Angefangen")
            case .unread:
                EmptyView()
            }
        }
    }
}

// MARK: - Topic List Row

private struct TopicListRow: View {
    let topic: KnowledgeTopic
    let progress: TopicProgress?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(topic.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(topic.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label("\(topic.readingMinutes) Min.", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(topic.level)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.2))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            statusIcon
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if let progress {
            switch progress.status {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Abgeschlossen")
            case .started:
                Image(systemName: "book.fill")
                    .foregroundColor(.accentColor)
                    .accessibilityLabel("Angefangen")
            case .unread:
                EmptyView()
            }
        }
    }
}

// MARK: - Category Card

private struct CategoryCard: View {
    let category: KnowledgeCategory

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.title2)
                .foregroundColor(.accentColor)

            Text(category.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(category.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.piratenSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let fakeRepo = FakeKnowledgeRepository()
    let progressStore = ReadingProgressStore()

    KnowledgeView(
        viewModel: KnowledgeViewModel(
            repository: fakeRepo,
            progressStore: progressStore
        )
    )
}
