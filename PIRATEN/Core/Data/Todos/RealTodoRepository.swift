//
//  RealTodoRepository.swift
//  PIRATEN
//
//  Created by Claude Code on 10.02.26.
//

import Foundation

/// Real implementation of TodoRepository using the meine-piraten.de REST API.
/// Uses TodoAPIClient for HTTP requests. Follows the same pattern as RealDiscourseRepository.
@MainActor
final class RealTodoRepository: TodoRepository {

    // MARK: - Dependencies

    private let apiClient: TodoAPIClient
    private let authRepository: AuthRepository

    // MARK: - Initialization

    init(apiClient: TodoAPIClient, authRepository: AuthRepository) {
        self.apiClient = apiClient
        self.authRepository = authRepository
    }

    // MARK: - Fetch

    func fetchTodos() async throws -> [Todo] {
        do {
            let data = try await apiClient.fetchTasks()
            let dtos = try decode([TaskDTO].self, from: data)
            return dtos.map { $0.toDomainModel() }
        } catch let error as TodoAPIError {
            throw mapToTodoError(error)
        }
    }

    func fetchTodos(completed: Bool) async throws -> [Todo] {
        let all = try await fetchTodos()
        if completed {
            return all.filter { $0.status == .done }
        } else {
            return all.filter { $0.status != .done }
        }
    }

    func fetchTodo(byId id: Int) async -> Todo? {
        do {
            let data = try await apiClient.fetchTask(id: id)
            let dto = try decode(TaskDTO.self, from: data)
            return dto.toDomainModel()
        } catch {
            return nil
        }
    }

    // MARK: - Create

    func createTodo(title: String, description: String?, entityId: Int, categoryId: Int, urgent: Bool, dueDate: Date?, activityPoints: Int?, timeNeededInHours: Int?) async throws -> Todo {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw TodoError.titleRequired }
        guard trimmedTitle.count <= 200 else { throw TodoError.titleTooLong }
        if let desc = description, desc.count > 2000 { throw TodoError.descriptionTooLong }

        var params: [String: Any] = [
            "title": trimmedTitle,
            "entity_id": entityId,
            "category_id": categoryId,
            "urgent": urgent,
            "status": "open"
        ]
        if let description = description {
            params["description"] = description
        }
        if let dueDate = dueDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            params["due_date"] = formatter.string(from: dueDate)
        }
        if let activityPoints = activityPoints {
            params["activity_points"] = activityPoints
        }
        if let timeNeededInHours = timeNeededInHours {
            params["time_needed_in_hours"] = timeNeededInHours
        }

        do {
            let data = try await apiClient.createTask(params: params)
            let dto = try decode(TaskDTO.self, from: data)
            return dto.toDomainModel()
        } catch let error as TodoAPIError {
            throw mapToTodoError(error)
        }
    }

    // MARK: - State Transitions

    func claimTodo(id: Int) async throws -> Todo {
        do {
            let username = await resolveUsername()
            let data = try await apiClient.updateTask(id: id, params: [
                "status": "claimed",
                "assignee": username
            ])
            let dto = try decode(TaskDTO.self, from: data)
            return dto.toDomainModel()
        } catch let error as TodoAPIError {
            throw mapToTodoError(error)
        }
    }

    func completeTodo(id: Int) async throws -> Todo {
        do {
            let data = try await apiClient.updateTask(id: id, params: [
                "status": "completed"
            ])
            let dto = try decode(TaskDTO.self, from: data)
            return dto.toDomainModel()
        } catch let error as TodoAPIError {
            throw mapToTodoError(error)
        }
    }

    func uncompleteTodo(id: Int) async throws -> Todo {
        do {
            let data = try await apiClient.updateTask(id: id, params: [
                "status": "claimed"
            ])
            let dto = try decode(TaskDTO.self, from: data)
            return dto.toDomainModel()
        } catch let error as TodoAPIError {
            throw mapToTodoError(error)
        }
    }

    func unclaimTodo(id: Int) async throws -> Todo {
        do {
            let data = try await apiClient.updateTask(id: id, params: [
                "status": "open",
                "assignee": NSNull()
            ])
            let dto = try decode(TaskDTO.self, from: data)
            return dto.toDomainModel()
        } catch let error as TodoAPIError {
            throw mapToTodoError(error)
        }
    }

    // MARK: - Deletion

    func deleteTodo(id: Int) async throws {
        do {
            try await apiClient.deleteTask(id: id)
        } catch let error as TodoAPIError {
            throw mapToTodoError(error)
        }
    }

    // MARK: - Comments

    func fetchComments(todoId: Int) async -> [TodoComment] {
        do {
            let data = try await apiClient.fetchComments(taskId: todoId)
            let dtos = try decode([CommentDTO].self, from: data)
            return dtos.map { $0.toDomainModel() }
        } catch {
            return []
        }
    }

    func addComment(todoId: Int, text: String) async throws -> TodoComment {
        do {
            let username = await resolveUsername()
            let data = try await apiClient.createComment(taskId: todoId, params: [
                "text": text,
                "author_name": username
            ])
            let dto = try decode(CommentDTO.self, from: data)
            return dto.toDomainModel()
        } catch let error as TodoAPIError {
            throw mapToTodoError(error)
        }
    }

    // MARK: - Admin Requests

    func checkAdminStatus() async -> Bool? {
        do {
            let data = try await apiClient.fetchAdminStatus()
            let result = try JSONDecoder().decode([String: Bool].self, from: data)
            return result["admin"]
        } catch {
            return nil
        }
    }

    func requestAdmin(reason: String) async throws {
        do {
            _ = try await apiClient.requestAdmin(reason: reason)
        } catch let error as TodoAPIError {
            throw mapToTodoError(error)
        }
    }

    // MARK: - Reference Data

    func fetchEntities() async -> [Entity] {
        do {
            let data = try await apiClient.fetchEntities()
            let dtos = try decode([EntityDTO].self, from: data)
            return dtos.map { $0.toDomainModel() }
        } catch {
            return []
        }
    }

    func fetchCategories() async -> [TodoCategory] {
        do {
            let data = try await apiClient.fetchCategories()
            let dtos = try decode([CategoryDTO].self, from: data)
            return dtos.map { $0.toDomainModel() }
        } catch {
            return []
        }
    }

    // MARK: - Private Helpers

    /// Resolves the current user's PiratenSSO username from the auth repository.
    /// Falls back to "unknown" if the user cannot be retrieved.
    private func resolveUsername() async -> String {
        if let user = await authRepository.getCurrentUser() {
            return user.username
        }
        return "unknown"
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw TodoAPIError.decodingError(message: error.localizedDescription)
        }
    }

    private func mapToTodoError(_ error: TodoAPIError) -> TodoError {
        switch error {
        case .unauthorized:
            return .unauthorized
        case .notFound:
            return .todoNotFound
        case .validationFailed(let message):
            return .operationFailed(message ?? "Validierungsfehler")
        default:
            return .operationFailed(error.localizedDescription)
        }
    }
}
