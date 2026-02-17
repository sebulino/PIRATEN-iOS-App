//
//  AdminRequestViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 17.02.26.
//

import Foundation
import Combine

/// ViewModel for the admin access request form.
@MainActor
final class AdminRequestViewModel: ObservableObject {

    // MARK: - Published State

    @Published var reason: String = ""
    @Published private(set) var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var didSubmitSuccessfully: Bool = false

    // MARK: - Dependencies

    private let todoRepository: TodoRepository

    // MARK: - Computed

    var canSubmit: Bool {
        !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    // MARK: - Initialization

    init(todoRepository: TodoRepository) {
        self.todoRepository = todoRepository
    }

    // MARK: - Actions

    func submit() {
        guard canSubmit else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await todoRepository.requestAdmin(reason: reason.trimmingCharacters(in: .whitespacesAndNewlines))
                didSubmitSuccessfully = true
            } catch {
                errorMessage = "Anfrage konnte nicht gesendet werden: \(error.localizedDescription)"
            }
            isSubmitting = false
        }
    }
}
