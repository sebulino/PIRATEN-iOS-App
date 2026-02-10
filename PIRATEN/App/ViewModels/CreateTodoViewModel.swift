//
//  CreateTodoViewModel.swift
//  PIRATEN
//
//  Created by Claude Code on 10.02.26.
//

import Foundation
import Combine

/// ViewModel for the Create Todo form.
/// Handles validation and submission of new todos.
@MainActor
final class CreateTodoViewModel: ObservableObject {

    // MARK: - Form State

    @Published var title: String = ""
    @Published var description: String = ""
    @Published var ownerType: OwnerType = .kreisverband
    @Published var ownerName: String = ""

    // MARK: - Submission State

    @Published private(set) var isSubmitting: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var didCreateSuccessfully: Bool = false

    // MARK: - Dependencies

    private let todoRepository: TodoRepository

    // MARK: - Initialization

    init(todoRepository: TodoRepository) {
        self.todoRepository = todoRepository
    }

    // MARK: - Validation

    var isTitleValid: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 200
    }

    var isOwnerNameValid: Bool {
        !ownerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canSubmit: Bool {
        isTitleValid && isOwnerNameValid && !isSubmitting
    }

    // MARK: - Actions

    func submit() {
        guard canSubmit else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let trimmedOwnerName = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
                let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
                let _ = try await todoRepository.createTodo(
                    title: title,
                    description: desc.isEmpty ? nil : desc,
                    ownerType: ownerType,
                    ownerId: trimmedOwnerName.lowercased().replacingOccurrences(of: " ", with: "-"),
                    ownerName: trimmedOwnerName
                )
                self.didCreateSuccessfully = true
            } catch let error as TodoError {
                switch error {
                case .titleRequired:
                    self.errorMessage = "Bitte einen Titel eingeben."
                case .titleTooLong:
                    self.errorMessage = "Der Titel darf maximal 200 Zeichen lang sein."
                case .descriptionTooLong:
                    self.errorMessage = "Die Beschreibung darf maximal 2000 Zeichen lang sein."
                default:
                    self.errorMessage = "Ein Fehler ist aufgetreten."
                }
            } catch {
                self.errorMessage = "Ein unerwarteter Fehler ist aufgetreten."
            }
            self.isSubmitting = false
        }
    }
}
