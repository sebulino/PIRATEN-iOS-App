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
    @Published var selectedEntityId: Int?
    @Published var selectedCategoryId: Int?
    @Published var urgent: Bool = false
    @Published var hasDueDate: Bool = false
    @Published var dueDate: Date = Date()
    @Published var activityPoints: Int = 0
    @Published var timeNeededInHours: Int = 0

    // MARK: - Reference Data

    @Published private(set) var entities: [Entity] = []
    @Published private(set) var categories: [TodoCategory] = []
    @Published private(set) var isLoadingReferenceData: Bool = false

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

    // MARK: - Data Loading

    func loadReferenceData() {
        guard entities.isEmpty else { return }
        isLoadingReferenceData = true
        Task {
            async let fetchedEntities = todoRepository.fetchEntities()
            async let fetchedCategories = todoRepository.fetchCategories()
            self.entities = await fetchedEntities
            self.categories = await fetchedCategories
            self.isLoadingReferenceData = false
        }
    }

    // MARK: - Validation

    var isTitleValid: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 200
    }

    var canSubmit: Bool {
        isTitleValid && selectedEntityId != nil && selectedCategoryId != nil && !isSubmitting
    }

    // MARK: - Actions

    func submit() {
        guard canSubmit,
              let entityId = selectedEntityId,
              let categoryId = selectedCategoryId else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
                let _ = try await todoRepository.createTodo(
                    title: title,
                    description: desc.isEmpty ? nil : desc,
                    entityId: entityId,
                    categoryId: categoryId,
                    urgent: urgent,
                    dueDate: hasDueDate ? dueDate : nil,
                    activityPoints: activityPoints > 0 ? activityPoints : nil,
                    timeNeededInHours: timeNeededInHours > 0 ? timeNeededInHours : nil
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
