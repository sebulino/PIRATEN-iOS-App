//
//  TodoDetailView.swift
//  PIRATEN
//
//  Created by Claude Code on 10.02.26.
//

import SwiftUI

/// Detail view for a single Todo.
/// Shows full information and actions based on the current status.
struct TodoDetailView: View {
    @StateObject var viewModel: TodoDetailViewModel

    init(viewModel: TodoDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Info section
                GroupBox("Aufgabe") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.todo.title)
                            .font(.headline)

                        if let description = viewModel.todo.description {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LabeledContent("Status") {
                        Text(viewModel.todo.status.displayName)
                            .foregroundColor(statusColor)
                            .fontWeight(.medium)
                    }

                    if let assignee = viewModel.todo.assignee {
                        LabeledContent("Zugewiesen an") {
                            Text(assignee)
                        }
                    }

                    if let dueDate = viewModel.todo.dueDate {
                        LabeledContent("Fällig") {
                            Text(dueDate, format: .dateTime.locale(Locale(identifier: "de_DE")).day().month(.wide).year())
                                .foregroundColor(dueDate < Date() && viewModel.todo.status != .done ? .red : .primary)
                        }
                    }

                    if let categoryName = viewModel.categoryName {
                        LabeledContent("Kategorie") {
                            Text(categoryName)
                        }
                    }

                    if let entityName = viewModel.entityName {
                        LabeledContent("Gliederung") {
                            Text(entityName)
                        }
                    }

                    LabeledContent("Erstellt") {
                        Text(viewModel.todo.createdAt, format: .dateTime.locale(Locale(identifier: "de_DE")).day().month(.wide).year())
                    }

                    if viewModel.todo.urgent {
                        LabeledContent("Dringend") {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                        }
                    }

                    if let points = viewModel.todo.activityPoints {
                        LabeledContent("Aktivitätspunkte") {
                            Text("\(points)")
                        }
                    }

                    if let hours = viewModel.todo.timeNeededInHours {
                        LabeledContent("Zeitaufwand") {
                            Text("\(hours) Std.")
                        }
                    }
                }

                // Actions section
                if viewModel.todo.status != .done {
                    GroupBox("Aktionen") {
                        actionsForStatus
                    }
                }

                // Comments section
                GroupBox("Kommentare") {
                    if viewModel.isLoadingComments {
                        ProgressView("Lade Kommentare...")
                    } else if viewModel.comments.isEmpty {
                        Text("Noch keine Kommentare.")
                            .foregroundColor(.secondary)
                            .font(.callout)
                    } else {
                        ForEach(viewModel.comments) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(comment.authorName)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(comment.createdAt, style: .relative)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text(comment.text)
                                    .font(.callout)
                            }
                        }
                    }

                    // Comment input
                    HStack {
                        TextField("Kommentar...", text: $viewModel.commentText)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            viewModel.sendComment()
                        } label: {
                            Image(systemName: "paperplane.fill")
                        }
                        .disabled(viewModel.commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSendingComment)
                    }
                }

                // Error display
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.callout)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
        .navigationTitle("Aufgabe")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(viewModel.isPerformingAction)
        .overlay {
            if viewModel.isPerformingAction {
                ProgressView()
            }
        }
        .onAppear {
            viewModel.loadComments()
            viewModel.loadReferenceData()
        }
    }

    @ViewBuilder
    private var actionsForStatus: some View {
        HStack(spacing: 12) {
            switch viewModel.todo.status {
            case .open:
                actionButton("Übernehmen", icon: "person.badge.plus", color: .piratenPrimary) {
                    viewModel.claim()
                }
            case .claimed:
                actionButton("Bearbeitet", icon: "checkmark.circle", color: .green) {
                    viewModel.complete()
                }
                actionButton("Freigeben", icon: "person.badge.minus", color: .piratenPrimary) {
                    viewModel.unclaim()
                }
            case .completed:
                actionButton("Nicht bearbeitet", icon: "arrow.uturn.backward", color: .piratenPrimary) {
                    viewModel.uncomplete()
                }
            case .done:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .foregroundStyle(color)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color, lineWidth: 1.5)
        )
    }

    private var statusColor: Color {
        switch viewModel.todo.status {
        case .open: return .piratenPrimary
        case .claimed: return .blue
        case .completed: return .green
        case .done: return .green
        }
    }
}

#Preview {
    NavigationStack {
        TodoDetailView(
            viewModel: TodoDetailViewModel(
                todo: Todo(
                    id: 1,
                    title: "Wahlkampfmaterial bestellen",
                    description: "Flyer und Plakate für den Infostand am Samstag vorbereiten.",
                    entityId: 1,
                    categoryId: 1,
                    createdAt: Date().addingTimeInterval(-86400 * 3),
                    dueDate: Date().addingTimeInterval(86400 * 4),
                    status: .open,
                    assignee: nil,
                    urgent: true,
                    activityPoints: 10,
                    timeNeededInHours: 2,
                    creatorName: "pirat42"
                ),
                todoRepository: FakeTodoRepository()
            )
        )
    }
}
