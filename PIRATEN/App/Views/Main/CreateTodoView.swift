//
//  CreateTodoView.swift
//  PIRATEN
//
//  Created by Claude Code on 10.02.26.
//

import SwiftUI

/// Form for creating a new Todo.
/// Presented as a sheet from the Todos tab.
struct CreateTodoView: View {
    @ObservedObject var viewModel: CreateTodoViewModel
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Aufgabe") {
                    TextField("Titel", text: $viewModel.title)
                        .textInputAutocapitalization(.sentences)

                    TextField("Beschreibung (optional)", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Organisation") {
                    Picker("Typ", selection: $viewModel.ownerType) {
                        ForEach(OwnerType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    TextField("Name der Organisation", text: $viewModel.ownerName)
                        .textInputAutocapitalization(.words)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("Neue Aufgabe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") {
                        viewModel.submit()
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
            .disabled(viewModel.isSubmitting)
            .overlay {
                if viewModel.isSubmitting {
                    ProgressView()
                }
            }
            .onChange(of: viewModel.didCreateSuccessfully) { _, success in
                if success {
                    onDismiss()
                }
            }
        }
    }
}

#Preview {
    CreateTodoView(
        viewModel: CreateTodoViewModel(todoRepository: FakeTodoRepository()),
        onDismiss: {}
    )
}
