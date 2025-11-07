//
//  TodoRepositoryTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation
import Testing
@testable import To_Do

@MainActor
@Suite("TodoRepository", .serialized)
struct TodoRepositoryTests {
    @Test
    func testInitialLoadFetchesFromAPIWhenStoreIsEmpty() async throws {
        let stack = TestCoreDataStack()
        let apiClient = MockTodoAPIClient()
        apiClient.result = .success([
            TodoDTO(id: 1, todo: "Buy milk", completed: false, userId: 1),
            TodoDTO(id: 2, todo: "Walk dog", completed: true, userId: 2)
        ])
        let (defaults, _) = makeIsolatedDefaults()
        let repository = TodoRepository(coreDataStack: stack, apiClient: apiClient, userDefaults: defaults)

        let items = try await loadInitialTodos(repository)

        #expect(items.count == 2)
        #expect(items.first?.title == "Buy milk")
        #expect(defaults.bool(forKey: "TodoRepository.initialLoad"))
    }

    @Test
    func testCreateTodoPersistsAndFetches() async throws {
        let (repository, _) = makeRepository()
        _ = try await createTodo(repository, title: "Test task", details: "Details")

        let items = try await fetchTodos(repository)

        #expect(items.count == 1)
        #expect(items.first?.title == "Test task")
    }

    @Test
    func testUpdateTodoChangesFields() async throws {
        let (repository, _) = makeRepository()
        var item = try await createTodo(repository, title: "Original", details: "Old")
        item.title = "Updated"
        item.details = "New details"
        item.isCompleted = true

        let updated = try await updateTodo(repository, item: item)

        #expect(updated.title == "Updated")
        #expect(updated.details == "New details")
        #expect(updated.isCompleted)
    }

    @Test
    func testDeleteTodoRemovesEntity() async throws {
        let (repository, _) = makeRepository()
        let item = try await createTodo(repository, title: "To delete", details: nil)

        try await deleteTodo(repository, item: item)

        let items = try await fetchTodos(repository)
        #expect(items.isEmpty)
    }

    @Test
    func testSearchFiltersByTitle() async throws {
        let (repository, _) = makeRepository()
        _ = try await createTodo(repository, title: "House work", details: nil)
        _ = try await createTodo(repository, title: "Grocery shopping", details: nil)

        let results = try await searchTodos(repository, query: "house")

        #expect(results.count == 1)
        #expect(results.first?.title == "House work")
    }
}

// Вспомогательные методы

@MainActor
private func makeRepository() -> (TodoRepository, String) {
    let stack = TestCoreDataStack()
    let apiClient = MockTodoAPIClient()
    let (defaults, suite) = makeIsolatedDefaults()
    let repository = TodoRepository(coreDataStack: stack, apiClient: apiClient, userDefaults: defaults)
    return (repository, suite)
}

@MainActor
private func makeIsolatedDefaults() -> (UserDefaults, String) {
    let suite = "TodoRepositoryTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else {
        fatalError("Failed to create UserDefaults for suite \(suite)")
    }
    return (defaults, suite)
}

@MainActor
private func loadInitialTodos(_ repository: TodoRepositoryProtocol) async throws -> [TodoItem] {
    try await withCheckedThrowingContinuation { continuation in
        repository.loadInitialTodos { result in
            continuation.resume(with: result)
        }
    }
}

@MainActor
private func fetchTodos(_ repository: TodoRepositoryProtocol) async throws -> [TodoItem] {
    try await withCheckedThrowingContinuation { continuation in
        repository.fetchTodos { result in
            continuation.resume(with: result)
        }
    }
}

@MainActor
private func createTodo(
    _ repository: TodoRepositoryProtocol,
    title: String,
    details: String?
) async throws -> TodoItem {
    try await withCheckedThrowingContinuation { continuation in
        repository.createTodo(title: title, details: details) { result in
            continuation.resume(with: result)
        }
    }
}

@MainActor
private func updateTodo(
    _ repository: TodoRepositoryProtocol,
    item: TodoItem
) async throws -> TodoItem {
    try await withCheckedThrowingContinuation { continuation in
        repository.updateTodo(item) { result in
            continuation.resume(with: result)
        }
    }
}

@MainActor
private func deleteTodo(
    _ repository: TodoRepositoryProtocol,
    item: TodoItem
) async throws {
    try await withCheckedThrowingContinuation { continuation in
        repository.deleteTodo(item) { result in
            continuation.resume(with: result)
        }
    }
}

@MainActor
private func searchTodos(
    _ repository: TodoRepositoryProtocol,
    query: String
) async throws -> [TodoItem] {
    try await withCheckedThrowingContinuation { continuation in
        repository.searchTodos(query: query) { result in
            continuation.resume(with: result)
        }
    }
}

