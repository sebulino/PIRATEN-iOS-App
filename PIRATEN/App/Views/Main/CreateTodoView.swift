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

                    Toggle("Dringend", isOn: $viewModel.urgent)
                }

                Section("Organisation") {
                    if viewModel.isLoadingReferenceData {
                        ProgressView("Lade...")
                    } else {
                        Picker("Gliederung", selection: $viewModel.selectedEntityId) {
                            Text("Bitte wählen").tag(nil as Int?)
                            ForEach(EntityLevel.allCases, id: \.self) { level in
                                let matching = viewModel.entities.filter { $0.entityLevel == level }
                                if !matching.isEmpty {
                                    Section(level.displayName) {
                                        ForEach(matching) { entity in
                                            Text(entity.name).tag(entity.id as Int?)
                                        }
                                    }
                                }
                            }
                        }

                        Picker("Kategorie", selection: $viewModel.selectedCategoryId) {
                            Text("Bitte wählen").tag(nil as Int?)
                            ForEach(viewModel.categories) { category in
                                Text(category.name).tag(category.id as Int?)
                            }
                        }
                    }
                }

                Section("Details") {
                    Toggle("Fälligkeitsdatum", isOn: $viewModel.hasDueDate)

                    if viewModel.hasDueDate {
                        DatePicker(
                            "Datum",
                            selection: $viewModel.dueDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aktivitätspunkte: \(viewModel.activityPoints == 0 ? "–" : "\(viewModel.activityPoints)")")
                        Slider(value: Binding(
                            get: { Double(viewModel.activityPoints == 0 ? 50 : viewModel.activityPoints) },
                            set: { viewModel.activityPoints = Int($0) }
                        ), in: 50...500, step: 10)
                    }

                    Stepper(
                        "Zeitaufwand: \(viewModel.timeNeededInHours == 0 ? "–" : "\(viewModel.timeNeededInHours) Std.")",
                        value: $viewModel.timeNeededInHours,
                        in: 0...20
                    )
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.piratenCallout)
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
            .onAppear {
                viewModel.loadReferenceData()
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
