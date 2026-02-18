//
//  ReplyComposerView.swift
//  PIRATEN
//
//  Created by Claude Code on 13.02.26.
//

import SwiftUI

/// Shared reply composer view for both PM and forum post replies.
/// Provides text input, validation, character counting, and send/cancel actions.
struct ReplyComposerView: View {
    @Binding var replyText: String
    let composerState: ReplyComposerState
    let canSend: Bool
    let characterCount: (current: Int, max: Int, isOverLimit: Bool)
    let validationError: String?
    var isFocused: FocusState<Bool>.Binding

    /// Optional context banner text (e.g., "Replying to @username (post #3)")
    let replyContext: String?

    let onSend: () -> Void
    let onCancel: () -> Void
    let onDismissError: () -> Void
    let onTextChanged: () -> Void

    init(
        replyText: Binding<String>,
        composerState: ReplyComposerState,
        canSend: Bool,
        characterCount: (current: Int, max: Int, isOverLimit: Bool),
        validationError: String?,
        isFocused: FocusState<Bool>.Binding,
        replyContext: String? = nil,
        onSend: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onDismissError: @escaping () -> Void,
        onTextChanged: @escaping () -> Void
    ) {
        self._replyText = replyText
        self.composerState = composerState
        self.canSend = canSend
        self.characterCount = characterCount
        self.validationError = validationError
        self.isFocused = isFocused
        self.replyContext = replyContext
        self.onSend = onSend
        self.onCancel = onCancel
        self.onDismissError = onDismissError
        self.onTextChanged = onTextChanged
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Reply context banner (e.g., "Replying to @username")
            if let context = replyContext {
                contextBanner(text: context)
            }

            // Error banner (shown when sending failed)
            if case .failed(let message) = composerState {
                errorBanner(message: message)
            }

            // Validation error (shown when input is invalid)
            if let validationError = validationError, composerState != .sending {
                validationBanner(message: validationError)
            }

            // Success banner (shown briefly after successful send)
            if composerState == .sent {
                successBanner
            }

            // Character count row (shown when approaching limit)
            if characterCount.current > characterCount.max / 2 || characterCount.isOverLimit {
                characterCountRow
            }

            // Composer input area
            HStack(alignment: .bottom, spacing: 12) {
                // Cancel button
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .disabled(composerState == .sending)
                .accessibilityLabel("Abbrechen")

                // Text input
                TextField("Nachricht schreiben...", text: $replyText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .focused(isFocused)
                    .disabled(composerState == .sending)
                    .onChange(of: replyText) { _, _ in
                        onTextChanged()
                    }
                    .onSubmit {
                        if canSend {
                            onSend()
                        }
                    }

                // Send button
                Button {
                    onSend()
                } label: {
                    Group {
                        if composerState == .sending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                    }
                    .font(.title2)
                }
                .disabled(!canSend)
                .accessibilityLabel("Senden")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    @ViewBuilder
    private func contextBanner(text: String) -> some View {
        HStack {
            Image(systemName: "arrowshape.turn.up.left")
                .foregroundColor(.blue)
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
    }

    @ViewBuilder
    private var characterCountRow: some View {
        HStack {
            Spacer()
            Text("\(characterCount.current)/\(characterCount.max)")
                .font(.caption2)
                .foregroundColor(characterCount.isOverLimit ? .red : .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text(message)
                .font(.caption)
                .foregroundColor(.white)
            Spacer()
            Button {
                onDismissError()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.red)
    }

    @ViewBuilder
    private func validationBanner(message: String) -> some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
    }

    @ViewBuilder
    private var successBanner: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
            Text("Nachricht gesendet")
                .font(.caption)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.green)
    }
}
