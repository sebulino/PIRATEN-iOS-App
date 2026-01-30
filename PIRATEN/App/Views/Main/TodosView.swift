//
//  TodosView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct TodosView: View {
    @ObservedObject var viewModel: TodosViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.todos.isEmpty {
                    ProgressView("Lade Aufgaben...")
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Erneut versuchen") {
                            viewModel.loadTodos()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    todosList
                }
            }
            .navigationTitle("Todos")
            .onAppear {
                if viewModel.todos.isEmpty {
                    viewModel.loadTodos()
                }
            }
        }
    }

    @ViewBuilder
    private var todosList: some View {
        List {
            // Pending tasks section
            if !viewModel.pendingTodos.isEmpty {
                Section("Offen") {
                    ForEach(viewModel.pendingTodos) { todo in
                        TodoRow(todo: todo)
                    }
                }
            }

            // Completed tasks section
            if !viewModel.completedTodos.isEmpty {
                Section("Erledigt") {
                    ForEach(viewModel.completedTodos) { todo in
                        TodoRow(todo: todo)
                    }
                }
            }
        }
        .refreshable {
            viewModel.refresh()
        }
    }
}

/// Row view for displaying a single todo in the list.
/// Shows task title, group name, and due date.
private struct TodoRow: View {
    let todo: Todo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Completion indicator
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : priorityIcon)
                    .foregroundColor(todo.isCompleted ? .green : priorityColor)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(todo.title)
                        .font(.headline)
                        .lineLimit(2)
                        .strikethrough(todo.isCompleted)
                        .foregroundColor(todo.isCompleted ? .secondary : .primary)

                    // Group name (placeholder data)
                    Text(todo.groupName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Due date if present
            if let dueDate = todo.dueDate {
                HStack {
                    Spacer()
                    dueDateLabel(dueDate)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Returns the appropriate icon based on priority
    private var priorityIcon: String {
        switch todo.priority {
        case .high:
            return "exclamationmark.circle"
        case .medium:
            return "circle"
        case .low:
            return "circle"
        }
    }

    /// Returns the appropriate color based on priority
    private var priorityColor: Color {
        switch todo.priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .blue
        }
    }

    /// Creates a due date label with appropriate styling for overdue items
    @ViewBuilder
    private func dueDateLabel(_ date: Date) -> some View {
        let isOverdue = date < Date() && !todo.isCompleted

        HStack(spacing: 4) {
            Image(systemName: isOverdue ? "clock.badge.exclamationmark" : "calendar")
            Text(date, style: .date)
        }
        .font(.caption)
        .foregroundColor(isOverdue ? .red : .secondary)
    }
}

#Preview {
    // Preview with fake data - uses FakeTodoRepository
    TodosView(viewModel: TodosViewModel(todoRepository: FakeTodoRepository()))
}
