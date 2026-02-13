//
//  TodosView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct TodosView: View {
    @ObservedObject var viewModel: TodosViewModel

    /// Factory for creating CreateTodoViewModels
    var createTodoViewModelFactory: (() -> CreateTodoViewModel)?

    /// Factory for creating TodoDetailViewModels
    var todoDetailViewModelFactory: ((Todo) -> TodoDetailViewModel)?

    @State private var showingCreateSheet = false

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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Neue Aufgabe erstellen")
                }
            }
            .sheet(isPresented: $showingCreateSheet, onDismiss: {
                viewModel.refresh()
            }) {
                if let factory = createTodoViewModelFactory {
                    CreateTodoView(viewModel: factory(), onDismiss: {
                        showingCreateSheet = false
                    })
                }
            }
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
            if !viewModel.pendingTodos.isEmpty {
                Section("Offen") {
                    ForEach(viewModel.pendingTodos) { todo in
                        todoNavigationLink(for: todo)
                    }
                }
            }

            if !viewModel.completedTodos.isEmpty {
                Section("Erledigt") {
                    ForEach(viewModel.completedTodos) { todo in
                        todoNavigationLink(for: todo)
                    }
                }
            }
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    @ViewBuilder
    private func todoNavigationLink(for todo: Todo) -> some View {
        if let factory = todoDetailViewModelFactory {
            NavigationLink {
                TodoDetailView(viewModel: factory(todo))
            } label: {
                TodoRow(todo: todo)
            }
        } else {
            TodoRow(todo: todo)
        }
    }
}

/// Row view for displaying a single todo in the list.
struct TodoRow: View {
    let todo: Todo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.title3)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(todo.title)
                        .font(.headline)
                        .lineLimit(2)
                        .strikethrough(todo.status == .done)
                        .foregroundStyle(todo.status == .done ? .secondary : .primary)

                    if let creatorName = todo.creatorName {
                        Text(creatorName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                statusBadge
            }

            if let dueDate = todo.dueDate {
                HStack {
                    Spacer()
                    dueDateLabel(dueDate)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        switch todo.status {
        case .done:
            return "checkmark.circle.fill"
        case .claimed:
            return "person.circle"
        case .open:
            return todo.urgent ? "exclamationmark.circle" : "circle"
        }
    }

    private var statusColor: Color {
        switch todo.status {
        case .done:
            return .green
        case .claimed:
            return .blue
        case .open:
            return todo.urgent ? .red : .orange
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        Text(todo.status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
            .accessibilityLabel("Status: \(todo.status.displayName)")
    }

    @ViewBuilder
    private func dueDateLabel(_ date: Date) -> some View {
        let isOverdue = date < Date() && todo.status != .done

        HStack(spacing: 4) {
            Image(systemName: isOverdue ? "clock.badge.exclamationmark" : "calendar")
                .accessibilityHidden(true)
            Text(date, style: .date)
        }
        .font(.caption)
        .foregroundStyle(isOverdue ? .red : .secondary)
        .accessibilityLabel(isOverdue ? "Überfällig: \(date.formatted(date: .long, time: .omitted))" : "Fällig: \(date.formatted(date: .long, time: .omitted))")
    }
}

#Preview {
    TodosView(viewModel: TodosViewModel(todoRepository: FakeTodoRepository()))
}
