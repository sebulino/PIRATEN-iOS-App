//
//  AdminRequestView.swift
//  PIRATEN
//
//  Created by Claude Code on 17.02.26.
//

import SwiftUI

/// Sheet view for requesting admin access on meine-piraten.de.
struct AdminRequestView: View {
    @ObservedObject var viewModel: AdminRequestViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Du kannst Admin-Rechte beantragen, um Aufgaben erstellen und verwalten zu können.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Begründung") {
                    TextEditor(text: $viewModel.reason)
                        .frame(minHeight: 100)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Admin-Rechte beantragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Senden") {
                        viewModel.submit()
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
            .overlay {
                if viewModel.isSubmitting {
                    ProgressView()
                }
            }
            .onChange(of: viewModel.didSubmitSuccessfully) { _, success in
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            }
            .alert("Anfrage gesendet", isPresented: .constant(viewModel.didSubmitSuccessfully)) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Deine Anfrage wurde erfolgreich gesendet. Ein Admin wird sie prüfen.")
            }
        }
    }
}
