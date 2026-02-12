//
//  CategoryDetailView.swift
//  PIRATEN
//

import SwiftUI

struct CategoryDetailView: View {
    let category: KnowledgeCategory
    let topics: [KnowledgeTopic]
    let progressStore: TopicProgressProvider
    var topicDetailViewModelFactory: ((KnowledgeTopic) -> KnowledgeTopicDetailViewModel)?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Category header
                categoryHeader
                    .padding(.bottom, 16)

                // Topic list
                if topics.isEmpty {
                    emptyState
                } else {
                    ForEach(topics) { topic in
                        topicRow(topic)
                        if topic.id != topics.last?.id {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Category Header

    @ViewBuilder
    private var categoryHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.largeTitle)
                .foregroundColor(.accentColor)

            Text(category.title)
                .font(.title2)
                .fontWeight(.bold)

            Text(category.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Topic Row

    @ViewBuilder
    private func topicRow(_ topic: KnowledgeTopic) -> some View {
        let progress = progressStore.progress(for: topic.id)

        if let factory = topicDetailViewModelFactory {
            NavigationLink {
                KnowledgeTopicDetailView(viewModel: factory(topic))
            } label: {
                topicRowContent(topic: topic, progress: progress)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            topicRowContent(topic: topic, progress: progress)
        }
    }

    @ViewBuilder
    private func topicRowContent(topic: KnowledgeTopic, progress: TopicProgress?) -> some View {
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
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            statusIcon(for: progress)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Status Icon

    @ViewBuilder
    private func statusIcon(for progress: TopicProgress?) -> some View {
        if let progress {
            switch progress.status {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
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

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("Keine Themen in dieser Kategorie")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(
            category: KnowledgeCategory(
                id: "kommunalpolitik",
                title: "Kommunalpolitik",
                description: "Grundlagen der kommunalen Selbstverwaltung und Mitbestimmung.",
                order: 1,
                icon: "building.2"
            ),
            topics: [
                KnowledgeTopic(
                    id: "grundlagen",
                    title: "Kommunalpolitik Grundlagen",
                    summary: "Einführung in die Arbeit auf kommunaler Ebene.",
                    categoryId: "kommunalpolitik",
                    tags: ["Kommune", "Gemeinderat"],
                    level: "Einsteiger",
                    readingMinutes: 8,
                    version: nil,
                    lastUpdated: nil,
                    quiz: nil,
                    relatedTopicIds: nil,
                    contentPath: "kommunalpolitik/grundlagen.md"
                )
            ],
            progressStore: PreviewProgressProvider()
        )
    }
}

private struct PreviewProgressProvider: TopicProgressProvider {
    func progress(for topicId: String) -> TopicProgress? { nil }
}
