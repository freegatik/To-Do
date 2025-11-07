//
//  TodoEditorInteractorTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation
import Testing
@testable import To_Do

@Suite("TodoEditorInteractor")
@MainActor
struct TodoEditorInteractorTests {
    @Test
    func testCreateModeInvokesRepositoryCreate() async throws {
        let repository = MockTodoRepository()
        let interactor = TodoEditorInteractor(repository: repository, mode: .create)
        let output = MockTodoEditorOutput()
        interactor.output = output

        let saved = try await withCheckedThrowingContinuation { continuation in
            output.onSave = { continuation.resume(returning: $0) }
            interactor.saveTodo(title: "New", details: "Desc", isCompleted: false)
        }

        #expect(repository.createCalled)
        #expect(saved.title == "New")
    }

    @Test
    func testEditModeInvokesRepositoryUpdate() async throws {
        let repository = MockTodoRepository()
        let original = TodoItem(id: 1, title: "Orig", details: nil, createdAt: Date(), isCompleted: false)
        let interactor = TodoEditorInteractor(repository: repository, mode: .edit(original))
        let output = MockTodoEditorOutput()
        interactor.output = output

        let saved = try await withCheckedThrowingContinuation { continuation in
            output.onSave = { continuation.resume(returning: $0) }
            interactor.saveTodo(title: "Edited", details: "Detail", isCompleted: true)
        }

        #expect(repository.updateCalled)
        #expect(saved.title == "Edited")
        #expect(saved.isCompleted == true)
    }
}

// Mocs

private final class MockTodoRepository: TodoRepositoryProtocol {
    var loadInitialCalled = false
    var fetchCalled = false
    var createCalled = false
    var updateCalled = false
    var toggleCalled = false
    var deleteCalled = false
    var searchCalled = false

    func loadInitialTodos(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        loadInitialCalled = true
        completion(.success([]))
    }

    func fetchTodos(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        fetchCalled = true
        completion(.success([]))
    }

    func createTodo(title: String, details: String?, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        createCalled = true
        completion(.success(TodoItem(id: 99, title: title, details: details, createdAt: Date(), isCompleted: false)))
    }

    func updateTodo(_ item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        updateCalled = true
        completion(.success(item))
    }

    func toggleCompletion(for item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        toggleCalled = true
        completion(.success(item))
    }

    func deleteTodo(_ item: TodoItem, completion: @escaping (Result<Void, Error>) -> Void) {
        deleteCalled = true
        completion(.success(()))
    }

    func searchTodos(query: String, completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        searchCalled = true
        completion(.success([]))
    }
}

private final class MockTodoEditorOutput: TodoEditorInteractorOutput {
    var lastError: Error?
    var onSave: ((TodoItem) -> Void)?

    func didLoad(todo: TodoItem?) { }

    func didSave(todo: TodoItem) {
        onSave?(todo)
    }

    func didFail(with error: Error) {
        lastError = error
    }
}

