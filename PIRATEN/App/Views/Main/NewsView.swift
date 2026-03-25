//
//  NewsView.swift
//  PIRATEN
//

import SwiftUI

struct NewsView: View {
    @ObservedObject var viewModel: NewsViewModel

    @Environment(\.dismiss) private var dismiss

    /// Tracks which news items the user has tapped into during this session
    @State private var viewedItemIds: Set<Int64> = []

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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Schließen")
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
                ForEach(viewModel.items.filter { !$0.headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { item in
                    NavigationLink(destination:
                        NewsDetailView(item: item)
                            .onAppear { viewedItemIds.insert(item.id) }
                    ) {
                        NewsCardView(item: item, isNew: viewModel.isNew(item) && !viewedItemIds.contains(item.id))
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
                .font(.piratenCaption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Retry") {
                viewModel.refresh()
            }
            .font(.piratenCaption)
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
