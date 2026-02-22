//
//  QuizCard.swift
//  PIRATEN
//

import SwiftUI

/// Multiple-choice quiz card with feedback, score display, and completion callback.
struct QuizCard: View {
    let questions: [QuizQuestion]
    let selectedAnswers: [UUID: Int]
    let isSubmitted: Bool
    let onSelectAnswer: (UUID, Int) -> Void
    let onComplete: () -> Void

    private var correctCount: Int {
        questions.filter { q in
            selectedAnswers[q.id] == q.correctAnswerIndex
        }.count
    }

    private var allAnswered: Bool {
        questions.allSatisfy { selectedAnswers[$0.id] != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Mini-Quiz", systemImage: "questionmark.circle.fill")
                .font(.headline)
                .foregroundColor(.piratenPrimary)

            ForEach(questions) { question in
                questionView(question)
            }

            if isSubmitted {
                scoreView
            } else {
                Button(action: onComplete) {
                    Text("Auswerten")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.piratenPrimary)
                .disabled(!allAnswered)
                .accessibilityLabel("Quiz auswerten")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func questionView(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.question)
                .font(.subheadline.weight(.medium))

            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                optionButton(question: question, index: index, option: option)
            }
        }
    }

    @ViewBuilder
    private func optionButton(question: QuizQuestion, index: Int, option: String) -> some View {
        let isSelected = selectedAnswers[question.id] == index
        let isCorrect = question.correctAnswerIndex == index

        Button {
            if !isSubmitted {
                onSelectAnswer(question.id, index)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: optionIcon(isSelected: isSelected, isCorrect: isCorrect))
                    .foregroundColor(optionColor(isSelected: isSelected, isCorrect: isCorrect))
                Text(option)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(optionBackground(isSelected: isSelected, isCorrect: isCorrect))
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSubmitted)
        .accessibilityLabel("\(option)\(isSubmitted && isCorrect ? ", richtige Antwort" : "")")
    }

    private func optionIcon(isSelected: Bool, isCorrect: Bool) -> String {
        if isSubmitted {
            if isCorrect { return "checkmark.circle.fill" }
            if isSelected { return "xmark.circle.fill" }
            return "circle"
        }
        return isSelected ? "largecircle.fill.circle" : "circle"
    }

    private func optionColor(isSelected: Bool, isCorrect: Bool) -> Color {
        if isSubmitted {
            if isCorrect { return .green }
            if isSelected { return .red }
            return .secondary
        }
        return isSelected ? .piratenPrimary : .secondary
    }

    private func optionBackground(isSelected: Bool, isCorrect: Bool) -> Color {
        if isSubmitted {
            if isCorrect { return .green.opacity(0.1) }
            if isSelected { return .red.opacity(0.1) }
            return .clear
        }
        return isSelected ? Color.piratenPrimary.opacity(0.1) : .clear
    }

    private var scoreView: some View {
        HStack {
            Image(systemName: correctCount == questions.count ? "star.fill" : "chart.bar.fill")
                .foregroundColor(correctCount == questions.count ? .piratenPrimary : .blue)
            Text("\(correctCount) von \(questions.count) richtig")
                .font(.subheadline.weight(.medium))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

#Preview {
    QuizCard(
        questions: [
            QuizQuestion(
                id: UUID(),
                question: "Was ist der Gemeinderat?",
                options: [
                    "Ein Bundesorgan",
                    "Das Parlament der Kommune",
                    "Eine Landesbehörde"
                ],
                correctAnswerIndex: 1
            )
        ],
        selectedAnswers: [:],
        isSubmitted: false,
        onSelectAnswer: { _, _ in },
        onComplete: {}
    )
    .padding()
}
