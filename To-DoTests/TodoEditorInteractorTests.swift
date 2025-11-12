//
//  TodoEditorInteractorTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation
import Testing
@testable import To_Do

/// Проверяем взаимодействие интерактора редактора задач с репозиторием
@Suite("TodoEditorInteractor")
@MainActor
struct TodoEditorInteractorTests {
    @Test
    /// В режиме создания интерактор сразу отдаёт nil
    func testLoadInitialInCreateModeEmitsNil() {
        let repository = MockTodoRepository()
        let interactor = TodoEditorInteractor(repository: repository, mode: .create)
        let output = MockTodoEditorOutput()
        interactor.output = output

        interactor.loadInitialTodo()

        #expect(output.didLoadTodos.count == 1)
        #expect(output.didLoadTodos == [nil])
        #expect(repository.loadInitialCalled == false)
    }

    @Test
    /// В режиме редактирования интерактор отдает исходную задачу
    func testLoadInitialInEditModeReturnsTodo() {
        let repository = MockTodoRepository()
        let todo = TodoItem(id: 42, title: "Orig", details: "Desc", createdAt: Date(), isCompleted: false)
        let interactor = TodoEditorInteractor(repository: repository, mode: .edit(todo))
        let output = MockTodoEditorOutput()
        interactor.output = output

        interactor.loadInitialTodo()

        #expect(output.didLoadTodos.count == 1)
        #expect(output.didLoadTodos.first??.id == todo.id)
    }

    @Test
    /// В режиме создания интерактор вызывает создание и возвращает результат через output
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
    /// В режиме редактирования интерактор обновляет задачу и передает обновленные данные
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

    @Test
    /// В режиме создания ошибки пробрасываются через output
    func testCreateModePropagatesFailure() {
        enum DummyError: Error { case failure }
        let repository = MockTodoRepository()
        repository.createResult = .failure(DummyError.failure)
        let interactor = TodoEditorInteractor(repository: repository, mode: .create)
        let output = MockTodoEditorOutput()
        interactor.output = output

        interactor.saveTodo(title: "New", details: nil, isCompleted: false)

        #expect(repository.createCalled)
        #expect(output.lastError is DummyError)
    }

    @Test
    /// В режиме редактирования ошибки обновления пробрасываются через output
    func testEditModePropagatesFailure() {
        enum DummyError: Error { case failure }
        let repository = MockTodoRepository()
        repository.updateResult = .failure(DummyError.failure)
        let original = TodoItem(id: 1, title: "Orig", details: nil, createdAt: Date(), isCompleted: false)
        let interactor = TodoEditorInteractor(repository: repository, mode: .edit(original))
        let output = MockTodoEditorOutput()
        interactor.output = output

        interactor.saveTodo(title: "Edit", details: nil, isCompleted: false)

        #expect(repository.updateCalled)
        #expect(output.lastError is DummyError)
    }

    @Test
    /// Интерактор вызывает toggleCompletion
    func testToggleCompletionDelegatesToRepository() {
        let repository = MockTodoRepository()
        let item = TodoItem(id: 7, title: "Toggle", details: nil, createdAt: Date(), isCompleted: false)
        let interactor = TodoEditorInteractor(repository: repository, mode: .edit(item))
        let output = MockTodoEditorOutput()
        interactor.output = output

        interactor.saveTodo(title: "Toggle", details: nil, isCompleted: true)

        #expect(repository.updateCalled)
        #expect(output.savedTodos.last?.isCompleted == true)
    }
}

// Mocs

/// Легковесный репозиторий, фиксирующий обращения интерактора
private final class MockTodoRepository: TodoRepositoryProtocol {
    var loadInitialCalled = false
    var fetchCalled = false
    var createCalled = false
    var updateCalled = false
    var toggleCalled = false
    var deleteCalled = false
    var searchCalled = false
    var createResult: Result<TodoItem, Error> = .success(TodoItem(id: 99, title: "New", details: nil, createdAt: Date(), isCompleted: false))
    var updateResult: Result<TodoItem, Error> = .success(TodoItem(id: 1, title: "Updated", details: nil, createdAt: Date(), isCompleted: false))

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
        completion(createResult.map { item in
            TodoItem(
                id: item.id,
                title: title,
                details: details,
                createdAt: item.createdAt,
                isCompleted: item.isCompleted
            )
        })
    }

    func updateTodo(_ item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        updateCalled = true
        completion(updateResult.map { _ in item })
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

/// Output-заглушка, позволяющая перехватить результат интерактора
private final class MockTodoEditorOutput: TodoEditorInteractorOutput {
    var lastError: Error?
    var onSave: ((TodoItem) -> Void)?
    var didLoadTodos: [TodoItem?] = []
    var savedTodos: [TodoItem] = []

    func didLoad(todo: TodoItem?) {
        didLoadTodos.append(todo)
    }

    func didSave(todo: TodoItem) {
        savedTodos.append(todo)
        onSave?(todo)
    }

    func didFail(with error: Error) {
        lastError = error
    }
}

