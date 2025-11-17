//
//  TodoListInteractorTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 11.11.2025.
//

import XCTest
@testable import To_Do

/// Проверяем, как интерактор списка задач взаимодействует с репозиторием
final class TodoListInteractorTests: XCTestCase {
    private var repository: MockRepository!
    private var output: MockOutput!
    private var sut: TodoListInteractor!

    override func setUp() {
        super.setUp()
        repository = MockRepository()
        output = MockOutput()
        sut = TodoListInteractor(repository: repository)
        sut.output = output
    }

    override func tearDown() {
        sut = nil
        output = nil
        repository = nil
        super.tearDown()
    }

    /// Успешная загрузка начальных задач передаётся во view через output
    func testLoadInitialTodosDeliversSuccessToOutput() {
        let expectedItems = [makeItem(id: 1), makeItem(id: 2)]
        repository.loadInitialTodosResult = .success(expectedItems)

        let updateExpectation = expectation(description: "didUpdateTodos invoked")
        output.onUpdate = { items in
            XCTAssertEqual(items, expectedItems)
            updateExpectation.fulfill()
        }

        sut.loadInitialTodos()

        wait(for: [updateExpectation], timeout: 0.1)
        XCTAssertEqual(repository.loadInitialTodosCallCount, 1)
    }

    /// После переключения статуса интерактор запрашивает свежие данные
    func testToggleCompletionSuccessRefreshesTodos() {
        let item = makeItem(id: 42)
        repository.toggleCompletionResult = .success(item)
        repository.fetchTodosResult = .success([item])

        let updateExpectation = expectation(description: "Refresh after toggle")
        output.onUpdate = { items in
            if items.first?.id == item.id {
                updateExpectation.fulfill()
            }
        }

        sut.toggleCompletion(for: item)

        wait(for: [updateExpectation], timeout: 0.1)
        XCTAssertEqual(repository.toggleCompletionCallCount, 1)
        XCTAssertEqual(repository.fetchTodosCallCount, 1)
        XCTAssertTrue(output.failures.isEmpty)
    }

    /// Ошибка переключения сообщает о проблеме через output
    func testToggleCompletionFailureNotifiesOutput() {
        let item = makeItem(id: 13)
        let expectedError = NSError(domain: "test", code: 1)
        repository.toggleCompletionResult = .failure(expectedError)

        let failureExpectation = expectation(description: "didFail called")
        output.onFailure = { error in
            XCTAssertEqual((error as NSError).code, expectedError.code)
            failureExpectation.fulfill()
        }

        sut.toggleCompletion(for: item)

        wait(for: [failureExpectation], timeout: 0.1)
        XCTAssertEqual(repository.toggleCompletionCallCount, 1)
        XCTAssertEqual(repository.fetchTodosCallCount, 0)
    }

    /// Успешное удаление приводит к повторной загрузке задач
    func testDeleteTodoSuccessTriggersRefresh() {
        let item = makeItem(id: 7)
        repository.deleteTodoResult = .success(())
        repository.fetchTodosResult = .success([])

        let updateExpectation = expectation(description: "Refresh after delete")
        output.onUpdate = { items in
            XCTAssertTrue(items.isEmpty)
            updateExpectation.fulfill()
        }

        sut.deleteTodo(item)

        wait(for: [updateExpectation], timeout: 0.1)
        XCTAssertEqual(repository.deleteTodoCallCount, 1)
        XCTAssertEqual(repository.fetchTodosCallCount, 1)
    }

    /// Поисковый запрос пробрасывается к репозиторию и результат возвращается в output
    func testSearchTodosForwardsRepositoryResult() {
        let items = [makeItem(id: 9)]
        repository.searchTodosResult = .success(items)

        let updateExpectation = expectation(description: "Search result delivered")
        output.onUpdate = { result in
            XCTAssertEqual(result, items)
            updateExpectation.fulfill()
        }

        sut.searchTodos(query: "test")

        wait(for: [updateExpectation], timeout: 0.1)
        XCTAssertEqual(repository.searchTodosCallCount, 1)
    }

    /// Ошибка удаления задачи передаётся в output
    func testDeleteTodoFailureNotifiesOutput() {
        let item = makeItem(id: 10)
        let expectedError = NSError(domain: "test", code: 2)
        repository.deleteTodoResult = .failure(expectedError)

        let failureExpectation = expectation(description: "didFail called on delete")
        output.onFailure = { error in
            XCTAssertEqual((error as NSError).code, expectedError.code)
            failureExpectation.fulfill()
        }

        sut.deleteTodo(item)

        wait(for: [failureExpectation], timeout: 0.1)
        XCTAssertEqual(repository.deleteTodoCallCount, 1)
        XCTAssertEqual(repository.fetchTodosCallCount, 0)
    }

    /// Ошибка загрузки начальных задач передаётся в output
    func testLoadInitialTodosFailureNotifiesOutput() {
        let expectedError = NSError(domain: "test", code: 3)
        repository.loadInitialTodosResult = .failure(expectedError)

        let failureExpectation = expectation(description: "didFail called on loadInitial")
        output.onFailure = { error in
            XCTAssertEqual((error as NSError).code, expectedError.code)
            failureExpectation.fulfill()
        }

        sut.loadInitialTodos()

        wait(for: [failureExpectation], timeout: 0.1)
        XCTAssertEqual(repository.loadInitialTodosCallCount, 1)
    }

    /// Ошибка обновления списка задач передаётся в output
    func testRefreshTodosFailureNotifiesOutput() {
        let expectedError = NSError(domain: "test", code: 4)
        repository.fetchTodosResult = .failure(expectedError)

        let failureExpectation = expectation(description: "didFail called on refresh")
        output.onFailure = { error in
            XCTAssertEqual((error as NSError).code, expectedError.code)
            failureExpectation.fulfill()
        }

        sut.refreshTodos()

        wait(for: [failureExpectation], timeout: 0.1)
        XCTAssertEqual(repository.fetchTodosCallCount, 1)
    }

    /// Ошибка поиска задач передаётся в output
    func testSearchTodosFailureNotifiesOutput() {
        let expectedError = NSError(domain: "test", code: 5)
        repository.searchTodosResult = .failure(expectedError)

        let failureExpectation = expectation(description: "didFail called on search")
        output.onFailure = { error in
            XCTAssertEqual((error as NSError).code, expectedError.code)
            failureExpectation.fulfill()
        }

        sut.searchTodos(query: "query")

        wait(for: [failureExpectation], timeout: 0.1)
        XCTAssertEqual(repository.searchTodosCallCount, 1)
    }
}

// Вспомогательные заглушки для тестов интерактора

/// Репозиторий, фиксирующий обращения интерактора
private final class MockRepository: TodoRepositoryProtocol {
    var loadInitialTodosResult: Result<[TodoItem], Error> = .success([])
    var fetchTodosResult: Result<[TodoItem], Error> = .success([])
    var createTodoResult: Result<TodoItem, Error> = .failure(NSError(domain: "unsupported", code: 0))
    var updateTodoResult: Result<TodoItem, Error> = .failure(NSError(domain: "unsupported", code: 0))
    var toggleCompletionResult: Result<TodoItem, Error> = .success(makeItem(id: 0))
    var deleteTodoResult: Result<Void, Error> = .success(())
    var searchTodosResult: Result<[TodoItem], Error> = .success([])

    private(set) var loadInitialTodosCallCount = 0
    private(set) var fetchTodosCallCount = 0
    private(set) var toggleCompletionCallCount = 0
    private(set) var deleteTodoCallCount = 0
    private(set) var searchTodosCallCount = 0

    func loadInitialTodos(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        loadInitialTodosCallCount += 1
        completion(loadInitialTodosResult)
    }

    func fetchTodos(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        fetchTodosCallCount += 1
        completion(fetchTodosResult)
    }

    func createTodo(title: String, details: String?, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        completion(createTodoResult)
    }

    func updateTodo(_ item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        completion(updateTodoResult)
    }

    func toggleCompletion(for item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        toggleCompletionCallCount += 1
        completion(toggleCompletionResult)
    }

    func deleteTodo(_ item: TodoItem, completion: @escaping (Result<Void, Error>) -> Void) {
        deleteTodoCallCount += 1
        completion(deleteTodoResult)
    }

    func searchTodos(query: String, completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        searchTodosCallCount += 1
        completion(searchTodosResult)
    }
}

/// Output-заглушка, собирающая события от интерактора
private final class MockOutput: TodoListInteractorOutput {
    var updates: [[TodoItem]] = []
    var failures: [Error] = []
    var onUpdate: (([TodoItem]) -> Void)?
    var onFailure: ((Error) -> Void)?

    func didUpdateTodos(_ items: [TodoItem]) {
        updates.append(items)
        onUpdate?(items)
    }

    func didFail(with error: Error) {
        failures.append(error)
        onFailure?(error)
    }
}

/// Утилита для создания тестовых задач
private func makeItem(id: Int64) -> TodoItem {
    TodoItem(
        id: id,
        title: "Title \(id)",
        details: nil,
        createdAt: Date(),
        isCompleted: false
    )
}

