//
//  FeedbackComposeView.swift
//  PIRATEN
//

import SwiftUI

struct FeedbackComposeView: View {
    @ObservedObject var viewModel: FeedbackViewModel
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .failed:
                    composeContent

                case .sending:
                    ProgressView("Sende Feedback...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .sent:
                    successContent
                }
            }
            .piratenStyledBackground()
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onDismiss()
                    }
                }
            }
        }
    }

    // MARK: - Compose Content

    @ViewBuilder
    private var composeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.feedbackType == .positive
                 ? "Was gefällt dir gerade?"
                 : "Was gefällt dir gerade nicht so?")
                .font(.piratenTitle3)
                .fontWeight(.bold)
                .foregroundColor(viewModel.feedbackType == .positive ? .green : .orange)

            TextEditor(text: $viewModel.bodyText)
                .font(.piratenBodyDefault)
                .frame(minHeight: 150)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGray6))
                .cornerRadius(8)

            if case .failed(let message) = viewModel.state {
                Text(message)
                    .font(.piratenCaption)
                    .foregroundColor(.red)
            }

            Button {
                Task { await viewModel.send() }
            } label: {
                Text("Senden")
                    .font(.piratenBodyDefault)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.piratenPrimary)
            .disabled(viewModel.bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()
        }
        .padding()
    }

    // MARK: - Success Content

    @ViewBuilder
    private var successContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Vielen Dank für dein Feedback!")
                .font(.piratenTitle3)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Button("Schließen") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.piratenPrimary)

            Spacer()
        }
        .padding()
    }
}
