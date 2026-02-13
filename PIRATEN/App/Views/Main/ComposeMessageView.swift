//
//  ComposeMessageView.swift
//  PIRATEN
//
//  Created by Claude Code on 02.02.26.
//

import SwiftUI

/// View for composing a new private message.
/// Shows recipient, subject, body fields with validation.
struct ComposeMessageView: View {
    @ObservedObject var viewModel: ComposeMessageViewModel
    @FocusState private var focusedField: Field?

    /// Callback to change recipient (opens picker)
    var onChangeRecipient: (() -> Void)?

    /// Callback when message is sent successfully, includes the new topic ID for navigation
    var onMessageSent: ((Int) -> Void)?

    /// Callback when cancel is tapped
    var onCancel: (() -> Void)?

    /// Whether to show cancel confirmation alert
    @State private var showCancelConfirmation = false

    /// Whether to show draft restore prompt
    @State private var showDraftRestorePrompt = false

    private enum Field {
        case subject
        case body
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Recipient section
                recipientSection

                Divider()

                // Subject field
                subjectSection

                Divider()

                // Body section
                bodySection

                Spacer()
            }
            .navigationTitle("Neue Nachricht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        handleCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.state == .sending {
                        ProgressView()
                    } else {
                        Button("Senden") {
                            viewModel.sendMessage()
                        }
                        .disabled(!viewModel.canSend)
                    }
                }
            }
            .alert("Nachricht verwerfen?", isPresented: $showCancelConfirmation) {
                Button("Abbrechen", role: .cancel) { }
                Button("Verwerfen", role: .destructive) {
                    viewModel.clearContent()
                    onCancel?()
                }
            } message: {
                Text("Die eingegebene Nachricht wird nicht gespeichert.")
            }
            .alert("Entwurf wiederherstellen?", isPresented: $showDraftRestorePrompt) {
                Button("Verwerfen", role: .destructive) {
                    viewModel.discardDraft()
                }
                Button("Wiederherstellen") {
                    viewModel.restoreFromDraft()
                }
            } message: {
                if let draft = viewModel.pendingDraft {
                    Text("Du hast einen ungesendeten Entwurf an @\(draft.recipientUsername).")
                } else {
                    Text("Du hast einen ungesendeten Entwurf.")
                }
            }
            .onChange(of: viewModel.state) { _, newState in
                if case .sent(let topicId) = newState {
                    onMessageSent?(topicId)
                }
            }
            .onAppear {
                viewModel.checkForDraft()
                if viewModel.hasPendingDraft {
                    showDraftRestorePrompt = true
                }
            }
            .onDisappear {
                // Save draft when leaving (unless message was sent)
                if case .sent = viewModel.state {
                    // Don't save draft if sent
                } else {
                    viewModel.saveDraft()
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var recipientSection: some View {
        Button {
            onChangeRecipient?()
        } label: {
            HStack(spacing: 12) {
                // Label
                Text("An:")
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .leading)

                if let recipient = viewModel.recipient {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(avatarColor(for: recipient.username))
                            .frame(width: 32, height: 32)

                        Text(initials(for: recipient))
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .accessibilityHidden(true)

                    // Name
                    Text(recipient.displayText)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Empfänger wählen...")
                        .foregroundColor(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var subjectSection: some View {
        HStack(spacing: 12) {
            Text("Betreff:")
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            TextField("", text: $viewModel.subject)
                .focused($focusedField, equals: .subject)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .body
                }
                .accessibilityLabel("Betreff")
        }
        .padding()
    }

    @ViewBuilder
    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Nachricht schreiben...", text: $viewModel.bodyText, axis: .vertical)
                .lineLimit(5...15)
                .focused($focusedField, equals: .body)
                .onChange(of: viewModel.bodyText) { _, _ in
                    viewModel.validateBody()
                }
                .accessibilityLabel("Nachrichtentext")

            // Error message
            if let error = viewModel.validationErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Character count
            if viewModel.shouldShowCharacterCount {
                let info = viewModel.characterCountInfo
                Text("\(info.current)/\(info.max)")
                    .font(.caption)
                    .foregroundColor(info.isOverLimit ? .red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Send error banner
            if case .failed(let message) = viewModel.state {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(message)
                    Spacer()
                    Button("OK") {
                        viewModel.dismissError()
                    }
                    .buttonStyle(.bordered)
                }
                .font(.caption)
                .foregroundColor(.red)
                .padding(.top, 8)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private func handleCancel() {
        if viewModel.hasContent {
            showCancelConfirmation = true
        } else {
            onCancel?()
        }
    }

    private func initials(for user: UserSearchResult) -> String {
        let name = user.displayName ?? user.username
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].first ?? Character(" ")
            let second = components[1].first ?? Character(" ")
            return "\(first)\(second)".uppercased()
        } else if let firstChar = name.first {
            return String(firstChar).uppercased()
        }
        return "?"
    }

    private func avatarColor(for username: String) -> Color {
        let hash = username.hashValue
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo]
        return colors[abs(hash) % colors.count]
    }
}

#Preview {
    let viewModel = ComposeMessageViewModel(
        discourseRepository: FakeDiscourseRepository(),
        recentRecipientsStorage: RecentRecipientsStore()
    )
    viewModel.recipient = UserSearchResult(
        username: "testuser",
        displayName: "Test User",
        avatarUrl: nil
    )
    return ComposeMessageView(viewModel: viewModel)
}
