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

    /// Callback when user taps the profile toolbar button
    var onProfileTapped: (() -> Void)?

    /// Callback when user taps the notifications toolbar button
    var onNotificationsTapped: (() -> Void)?

    /// Whether to show a badge on the notification bell
    var notificationsBadge: Bool = false

    /// Callback when user taps the home button to navigate to Kajüte
    var onHomeTapped: (() -> Void)?

    /// Callback when user taps the messages button to open Nachrichten
    var onMessagesTapped: (() -> Void)?

    @State private var showingCreateSheet = false

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.loadState {
                case .idle, .loading:
                    if viewModel.todos.isEmpty {
                        ProgressView("Lade Aufgaben...")
                    } else {
                        todosList
                    }

                case .loaded:
                    if viewModel.todos.isEmpty {
                        emptyState
                    } else {
                        todosList
                    }

                case .error(let message):
                    errorState(message: message)
                }
            }
            .piratenStyledBackground()
            .navigationTitle("Todos")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 2) {
                        PiratenIconButton(
                            systemName: "house",
                            accessibilityLabel: "Kajüte"
                        ) {
                            onHomeTapped?()
                        }
                        PiratenIconButton(
                            systemName: "envelope",
                            accessibilityLabel: "Nachrichten"
                        ) {
                            onMessagesTapped?()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 2) {
                        PiratenIconButton(
                            systemName: notificationsBadge ? "bell.badge" : "bell",
                            badge: notificationsBadge,
                            accessibilityLabel: "Benachrichtigungen"
                        ) {
                            onNotificationsTapped?()
                        }

                        PiratenIconButton(
                            systemName: "person.circle",
                            accessibilityLabel: "Profil"
                        ) {
                            onProfileTapped?()
                        }

                        PiratenIconButton(
                            systemName: "plus",
                            accessibilityLabel: "Neue Aufgabe erstellen"
                        ) {
                            showingCreateSheet = true
                        }
                    }
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
                if viewModel.loadState == .idle {
                    viewModel.loadTodos()
                }
            }
        }
    }

    // MARK: - State Views

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Keine Aufgaben")
                .font(.headline)
            Text("Es sind noch keine Aufgaben vorhanden.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Aktualisieren") {
                viewModel.refresh()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    @ViewBuilder
    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Color.piratenPrimary)
                .accessibilityHidden(true)
            Text("Fehler beim Laden")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") {
                viewModel.loadTodos()
            }
            .buttonStyle(.bordered)
        }
        .padding()
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
        .scrollContentBackground(.hidden)
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
    var categoryName: String?
    var entityName: String?
    var hideStatus: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if !hideStatus {
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)
                        .font(.title3)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(todo.title)
                        .font(hideStatus ? .subheadline : .headline)
                        .fontWeight(hideStatus ? .medium : .regular)
                        .lineLimit(2)
                        .strikethrough(todo.status == .done)
                        .foregroundStyle(todo.status == .done ? .secondary : .primary)
                }

                Spacer()

                if !hideStatus {
                    statusBadge
                }
            }

            // Metadata row: category, entity, time needed
            if categoryName != nil || entityName != nil || todo.timeNeededInHours != nil {
                HStack(spacing: 12) {
                    if let name = categoryName {
                        Label(name, systemImage: "tag")
                    }
                    if let name = entityName {
                        Label(name, systemImage: "building.2")
                    }
                    if let hours = todo.timeNeededInHours {
                        Label("\(hours) Std.", systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
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
        case .completed:
            return "checkmark.circle"
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
        case .completed:
            return .green
        case .claimed:
            return .blue
        case .open:
            return todo.urgent ? .red : .piratenPrimary
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
