//
//  KnowledgeTopicDetailView.swift
//  PIRATEN
//

import SwiftUI

struct KnowledgeTopicDetailView: View {
    @ObservedObject var viewModel: KnowledgeTopicDetailViewModel

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .idle, .loading:
                loadingView
            case .loaded:
                contentView
            case .error(let message):
                errorView(message: message)
            }
        }
        .navigationTitle(viewModel.topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.markAsStarted()
            if viewModel.content == nil {
                viewModel.loadContent()
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.topic.title)
                .font(.title2)
                .fontWeight(.bold)

            // Tags
            if !viewModel.topic.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.topic.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Level + reading time
            HStack(spacing: 12) {
                Text(viewModel.topic.level)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .clipShape(Capsule())

                Label("\(viewModel.topic.readingMinutes) Min.", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                headerView
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if let content = viewModel.content {
                    ForEach(Array(content.sections.enumerated()), id: \.offset) { index, section in
                        sectionView(section, at: index)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Section Rendering

    @ViewBuilder
    private func sectionView(_ section: ContentSection, at index: Int) -> some View {
        switch section {
        case .overview(let bullets):
            OverviewCard(bullets: bullets)

        case .text(let heading, let body):
            SectionCard(
                heading: heading,
                isExpanded: viewModel.isSectionExpanded(index),
                onToggle: { viewModel.toggleSection(index) }
            ) {
                MarkdownTextView(markdown: body)
                    .font(.subheadline)
            }

        case .checklist(let items):
            ChecklistCard(
                items: items,
                isCompleted: { viewModel.isChecklistItemCompleted($0) },
                onToggle: { viewModel.toggleChecklistItem($0) }
            )

        case .callout(let type, let text):
            CalloutView(type: type, text: text)

        case .quiz(let questions):
            QuizCard(
                questions: questions,
                selectedAnswers: viewModel.selectedAnswers,
                isSubmitted: viewModel.quizSubmitted,
                onSelectAnswer: { questionId, answerIndex in
                    viewModel.selectedAnswers[questionId] = answerIndex
                },
                onComplete: { viewModel.submitQuiz() }
            )

        case .nextSteps(let topicIds):
            NextStepsCard(topicIds: topicIds)
        }
    }

    // MARK: - Loading

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Inhalt wird geladen...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") {
                viewModel.loadContent()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NavigationStack {
        KnowledgeTopicDetailView(
            viewModel: KnowledgeTopicDetailViewModel(
                topic: KnowledgeTopic(
                    id: "grundlagen",
                    title: "Kommunalpolitik Grundlagen",
                    summary: "Einführung in die Arbeit auf kommunaler Ebene.",
                    categoryId: "kommunalpolitik",
                    tags: ["Kommune", "Gemeinderat", "Demokratie"],
                    level: "Einsteiger",
                    readingMinutes: 8,
                    version: nil,
                    lastUpdated: nil,
                    quiz: [
                        QuizQuestion(
                            id: UUID(),
                            question: "Was ist der Gemeinderat?",
                            options: ["Ein Bundesorgan", "Das Parlament der Kommune", "Eine Landesbehörde"],
                            correctAnswerIndex: 1
                        )
                    ],
                    relatedTopicIds: ["antragsformulierung"],
                    contentPath: "kommunalpolitik/grundlagen.md"
                ),
                repository: FakeKnowledgeRepository(),
                progressStore: ReadingProgressStore()
            )
        )
    }
}
