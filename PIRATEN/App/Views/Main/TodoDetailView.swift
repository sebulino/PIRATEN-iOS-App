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
    @ObservedObject var viewModel: TodoDetailViewModel

    var body: some View {
        List {
            // Info section
            Section("Aufgabe") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.todo.title)
                        .font(.headline)

                    if let description = viewModel.todo.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }

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
                        Text(dueDate, style: .date)
                            .foregroundColor(dueDate < Date() && viewModel.todo.status != .done ? .red : .primary)
                    }
                }

                LabeledContent("Erstellt") {
                    Text(viewModel.todo.createdAt, style: .date)
                }

                if let creatorName = viewModel.todo.creatorName {
                    LabeledContent("Erstellt von") {
                        Text(creatorName)
                    }
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
                Section("Aktionen") {
                    actionsForStatus
                }
            }

            // Comments section
            Section {
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
            } header: {
                Text("Kommentare")
            }

            // Error display
            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.callout)
                }
            }
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
        }
    }

    @ViewBuilder
    private var actionsForStatus: some View {
        switch viewModel.todo.status {
        case .open:
            Button {
                viewModel.claim()
            } label: {
                Label("Übernehmen", systemImage: "person.badge.plus")
            }
        case .claimed:
            Button {
                viewModel.complete()
            } label: {
                Label("Erledigt", systemImage: "checkmark.circle")
            }
            .tint(.green)

            Button {
                viewModel.unclaim()
            } label: {
                Label("Freigeben", systemImage: "person.badge.minus")
            }
            .tint(.orange)
        case .done:
            EmptyView()
        }
    }

    private var statusColor: Color {
        switch viewModel.todo.status {
        case .open: return .orange
        case .claimed: return .blue
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
