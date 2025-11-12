//
//  TodoRepositoryTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 11.11.2025.
//

import XCTest
import CoreData
@testable import To_Do

private enum RepositoryTestError: Error {
    case failure
}

/// Интеграционные тесты репозитория задач поверх Core Data
@MainActor
final class TodoRepositoryTests: XCTestCase {
    /// Если база пуста, первый запуск тянет задачи из API и сохраняет их
    func testInitialLoadFetchesFromAPIWhenStoreIsEmpty() async throws {
        let (repository, apiClient, defaults) = await makeRepository()
        apiClient.result = .success([
            TodoDTO(id: 1, todo: "Buy milk", completed: false, userId: 1),
            TodoDTO(id: 2, todo: "Walk dog", completed: true, userId: 2)
        ])

        let items = try await loadInitialTodos(repository)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.title, "Buy milk")
        XCTAssertEqual(apiClient.fetchCallCount, 1)
        XCTAssertTrue(defaults.bool(forKey: "TodoRepository.initialLoad"))
    }

    /// Создание задачи сохраняет её и позволяет получить через fetch
    func testCreateTodoPersistsAndFetches() async throws {
        let (repository, _, _) = await makeRepository()

        _ = try await createTodo(repository, title: "Test task", details: "Details")

        let items = try await fetchTodos(repository)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.title, "Test task")
    }

    /// Обновление задачи перезаписывает поля и возвращает обновлённую модель
    func testUpdateTodoChangesFields() async throws {
        let (repository, _, _) = await makeRepository()

        var item = try await createTodo(repository, title: "Original", details: "Old")
        item.title = "Updated"
        item.details = "New details"
        item.isCompleted = true

        let updated = try await updateTodo(repository, item: item)

        XCTAssertEqual(updated.title, "Updated")
        XCTAssertEqual(updated.details, "New details")
        XCTAssertTrue(updated.isCompleted)
    }

    /// Удаление задачи удаляет запись из Core Data
    func testDeleteTodoRemovesEntity() async throws {
        let (repository, _, _) = await makeRepository()

        let item = try await createTodo(repository, title: "To delete", details: nil)

        try await deleteTodo(repository, item: item)

        let items = try await fetchTodos(repository)
        XCTAssertEqual(items.count, 0)
    }

    /// Поиск фильтрует результаты по совпадению в заголовке
    func testSearchFiltersByTitle() async throws {
        let (repository, _, _) = await makeRepository()

        _ = try await createTodo(repository, title: "House work", details: nil)
        _ = try await createTodo(repository, title: "Grocery shopping", details: nil)

        let results = try await searchTodos(repository, query: "house")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "House work")
    }

    /// Поиск учитывает описание и игнорирует диакритические символы
    func testSearchMatchesDetailsAndIgnoresDiacritics() async throws {
        let (repository, _, _) = await makeRepository()

        _ = try await createTodo(repository, title: "First", details: "Найти café на углу")
        _ = try await createTodo(repository, title: "Second", details: "Без описания")

        let results = try await searchTodos(repository, query: "CAFE")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.details, "Найти café на углу")
    }

    /// При ошибке API репозиторий возвращает ту же ошибку
    func testInitialLoadPropagatesAPIFailure() async throws {
        let (repository, apiClient, _) = await makeRepository()
        apiClient.result = .failure(RepositoryTestError.failure)

        do {
            _ = try await loadInitialTodos(repository)
            XCTFail("Expected loadInitialTodos to throw")
        } catch RepositoryTestError.failure {
            // success
        }
        XCTAssertEqual(apiClient.fetchCallCount, 1)
    }

    /// Если данные уже есть, повторный старт не вызывает API
    func testInitialLoadSkipsAPIAfterDataExists() async throws {
        let (repository, apiClient, defaults) = await makeRepository()
        _ = try await createTodo(repository, title: "Seed", details: nil)

        apiClient.reset()
        let items = try await loadInitialTodos(repository)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(apiClient.fetchCallCount, 0)
        XCTAssertTrue(defaults.bool(forKey: "TodoRepository.initialLoad"))
    }

    /// Когда флаг initialLoad установлен, используется локальное хранилище
    func testInitialLoadWhenFlagSetUsesStoredTodos() async throws {
        let (repository, apiClient, defaults) = await makeRepository()
        _ = try await createTodo(repository, title: "Already loaded", details: "check")

        defaults.set(true, forKey: "TodoRepository.initialLoad")
        apiClient.reset()

        let items = try await loadInitialTodos(repository)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(apiClient.fetchCallCount, 0)
    }

    /// Аргумент --uitest пропускает загрузку с сервера
    func testLoadInitialTodosWhenUITestFlagSkipsAPIFetch() async throws {
#if DEBUG
        let stack = PreloadedCoreDataStack(seedCount: 2)
        let (repository, apiClient, defaults) = await makeRepository(stack: stack)
        apiClient.reset()

        TodoRepository.isUITestOverride = true
        defer { TodoRepository.isUITestOverride = nil }

        let items = try await loadInitialTodos(repository)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(apiClient.fetchCallCount, 0)
        XCTAssertTrue(defaults.bool(forKey: "TodoRepository.initialLoad"))
#else
        throw XCTSkip("UI-test override недоступен в релизной сборке")
#endif
    }

    /// Ошибка Core Data при fetch пробрасывается вызывающему коду
    func testFetchTodosPropagatesCoreDataError() async throws {
        let (repository, _, _) = await makeRepository()
        TodoRepository.debugFailure = .fetchTodos(RepositoryTestError.failure)
        defer { TodoRepository.debugFailure = nil }

        do {
            _ = try await fetchTodos(repository)
            XCTFail("Expected fetchTodos to throw")
        } catch RepositoryTestError.failure {
            // expected
        }
    }

    /// Ошибка сохранения при создании задачи долетает до completion
    func testCreateTodoPropagatesCoreDataError() async throws {
        let (repository, _, _) = await makeRepository()
        TodoRepository.debugFailure = .createTodo(RepositoryTestError.failure)
        defer { TodoRepository.debugFailure = nil }

        do {
            _ = try await createTodo(repository, title: "Fail", details: nil)
            XCTFail("Expected createTodo to throw")
        } catch RepositoryTestError.failure {
            // expected
        }
    }

    /// Ошибки обновления Core Data не скрываются
    func testUpdateTodoPropagatesCoreDataError() async throws {
        let (repository, _, _) = await makeRepository()
        TodoRepository.debugFailure = .updateTodo(RepositoryTestError.failure)
        defer { TodoRepository.debugFailure = nil }
        let item = TodoItem(id: 1, title: "Seed", details: "details", createdAt: Date(), isCompleted: false)

        do {
            _ = try await updateTodo(repository, item: item)
            XCTFail("Expected updateTodo to throw")
        } catch RepositoryTestError.failure {
            // expected
        }
    }

    /// Ошибки удаления также возвращаются наружу
    func testDeleteTodoPropagatesCoreDataError() async throws {
        let (repository, _, _) = await makeRepository()
        TodoRepository.debugFailure = .deleteTodo(RepositoryTestError.failure)
        defer { TodoRepository.debugFailure = nil }
        let item = TodoItem(id: 1, title: "Remove me", details: nil, createdAt: Date(), isCompleted: false)

        do {
            try await deleteTodo(repository, item: item)
            XCTFail("Expected deleteTodo to throw")
        } catch RepositoryTestError.failure {
            // expected
        }
    }

    /// Ошибку поиска репозиторий пробрасывает вызывающему
    func testSearchTodosPropagatesCoreDataError() async throws {
        let (repository, _, _) = await makeRepository()
        TodoRepository.debugFailure = .searchTodos(RepositoryTestError.failure)
        defer { TodoRepository.debugFailure = nil }

        do {
            _ = try await searchTodos(repository, query: "query")
            XCTFail("Expected searchTodos to throw")
        } catch RepositoryTestError.failure {
            // expected
        }
    }

    /// Если фоновый контекст не может получить данные, возвращаем ошибку
    func testFetchTodosWhenBackgroundFetchFailsReturnsError() async {
        let failingStack = FailingCoreDataStack(throwOnFetch: true)
        let (repository, _, _) = await makeRepository(stack: failingStack)

        do {
            _ = try await fetchTodos(repository)
            XCTFail("Expected fetchTodos to throw")
        } catch RepositoryTestError.failure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Ошибка сохранения при создании приводит к failure результату
    func testCreateTodoWhenSaveFailsReturnsError() async {
        let failingStack = FailingCoreDataStack(throwOnSave: true)
        let (repository, _, _) = await makeRepository(stack: failingStack)

        do {
            _ = try await createTodo(repository, title: "Failing", details: nil)
            XCTFail("Expected createTodo to throw")
        } catch RepositoryTestError.failure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Обновление несуществующей сущности возвращает entityNotFound
    func testUpdateTodoWhenEntityMissingReturnsEntityNotFound() async {
        let (repository, _, _) = await makeRepository()
        let phantom = TodoItem(id: 999, title: "Missing", details: nil, createdAt: Date(), isCompleted: false)

        do {
            _ = try await updateTodo(repository, item: phantom)
            XCTFail("Expected updateTodo to throw")
        } catch let error as TodoRepositoryError {
            XCTAssertEqual(error, .entityNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Удаление несуществующей сущности возвращает entityNotFound
    func testDeleteTodoWhenEntityMissingReturnsEntityNotFound() async {
        let (repository, _, _) = await makeRepository()
        let phantom = TodoItem(id: 321, title: "Ghost", details: nil, createdAt: Date(), isCompleted: false)

        do {
            try await deleteTodo(repository, item: phantom)
            XCTFail("Expected deleteTodo to throw")
        } catch let error as TodoRepositoryError {
            XCTAssertEqual(error, .entityNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Переключение статуса изменяет флаг и сохраняет результат
    func testToggleCompletionFlipsAndPersistsFlag() async throws {
        let (repository, _, _) = await makeRepository()

        let original = try await createTodo(repository, title: "Toggle me", details: nil)
        XCTAssertFalse(original.isCompleted)

        let toggled = try await toggleCompletion(repository, item: original)
        XCTAssertTrue(toggled.isCompleted)

        let refreshed = try await fetchTodos(repository)
        XCTAssertEqual(refreshed.first?.isCompleted, true)
    }

    /// Даже если подсчёт падает, отладочная опция заставляет грузить API
    func testLoadInitialTodosWhenCountThrowsDebugOverrideStillLoadsFromAPI() async throws {
        let failingStack = FailingCoreDataStack(throwOnCount: true)
        let (repository, apiClient, _) = await makeRepository(stack: failingStack)
        apiClient.result = .success([
            TodoDTO(id: 1, todo: "First", completed: false, userId: 1),
            TodoDTO(id: 2, todo: "Second", completed: true, userId: 1)
        ])
#if DEBUG
        TodoRepository.debugCountTodosError = RepositoryTestError.failure
        let debugItems = try await loadInitialTodos(repository)
        XCTAssertEqual(debugItems.count, 2)
        XCTAssertEqual(apiClient.fetchCallCount, 1)
        XCTAssertNil(TodoRepository.debugCountTodosError)
#endif

        let secondStack = FailingCoreDataStack(throwOnCount: true)
        let (secondRepository, secondApiClient, _) = await makeRepository(stack: secondStack)
        secondApiClient.result = .success([
            TodoDTO(id: 10, todo: "Alt First", completed: false, userId: 1),
            TodoDTO(id: 11, todo: "Alt Second", completed: true, userId: 1)
        ])

        let items = try await loadInitialTodos(secondRepository)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(secondApiClient.fetchCallCount, 1)
    }

    /// При ошибке count репозиторий всё равно делает загрузку и сохраняет флаг
    func testLoadInitialTodosWhenCountThrowsStillLoadsFromAPI() async throws {
        let failingStack = FailingCoreDataStack(throwOnCount: true)
        let (repository, apiClient, _) = await makeRepository(stack: failingStack)
        apiClient.result = .success([
            TodoDTO(id: 1, todo: "First", completed: false, userId: 1),
            TodoDTO(id: 2, todo: "Second", completed: true, userId: 1)
        ])

        let items = try await loadInitialTodos(repository)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(apiClient.fetchCallCount, 1)
    }

    /// Ошибка сохранения стартовых данных приводит к failure
    func testLoadInitialTodosWhenSavingInitialDataFailsReturnsError() async {
        let failingStack = FailingCoreDataStack(throwOnSave: true)
        let (repository, apiClient, _) = await makeRepository(stack: failingStack)
        apiClient.result = .success([
            TodoDTO(id: 1, todo: "Seed", completed: false, userId: 1)
        ])

        do {
            _ = try await loadInitialTodos(repository)
            XCTFail("Expected loadInitialTodos to throw")
        } catch RepositoryTestError.failure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(apiClient.fetchCallCount, 1)
    }

    /// Ошибка выборки при поиске также пробрасывается
    func testSearchTodosWhenFetchFailsReturnsError() async {
        let failingStack = FailingCoreDataStack(throwOnViewFetch: true)
        let (repository, _, _) = await makeRepository(stack: failingStack)

        do {
            _ = try await searchTodos(repository, query: "anything")
            XCTFail("Expected searchTodos to throw")
        } catch RepositoryTestError.failure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Новый todo получает следующий доступный идентификатор
    func testCreateTodoAssignsIncrementalIdentifier() async throws {
        let (repository, _, _) = await makeRepository()

        let first = try await createTodo(repository, title: "First", details: nil)
        let second = try await createTodo(repository, title: "Second", details: nil)

        XCTAssertEqual(first.id, 1)
        XCTAssertEqual(second.id, 2)
    }

    /// Completion при создании вызывается на главном потоке
    func testCreateTodoCompletionRunsOnMainThread() async {
        let (repository, _, _) = await makeRepository()
        let expectation = expectation(description: "completion on main")

        repository.createTodo(title: "Main", details: nil) { result in
            XCTAssertTrue(Thread.isMainThread)
            if case .failure(let error) = result {
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1)
    }

    /// Fetch возвращает отсортированные элементы и завершает на главном потоке
    func testFetchTodosDeliversSortedItemsOnMainThread() async throws {
        let (repository, _, _) = await makeRepository()
        _ = try await createTodo(repository, title: "First", details: nil)
        try await Task.sleep(nanoseconds: 10_000_000)
        _ = try await createTodo(repository, title: "Second", details: nil)

        let expectation = expectation(description: "fetch")
        repository.fetchTodos { result in
            XCTAssertTrue(Thread.isMainThread)
            switch result {
            case .success(let items):
                XCTAssertEqual(items.map(\.title), ["Second", "First"])
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1)
    }

    /// Пустой или пробельный запрос возвращает все элементы
    func testSearchTodosWithWhitespaceReturnsAllItems() async throws {
        let (repository, _, _) = await makeRepository()
        _ = try await createTodo(repository, title: "Alpha", details: nil)
        _ = try await createTodo(repository, title: "Beta", details: "Task")

        let expectation = expectation(description: "search")
        repository.searchTodos(query: "   ") { result in
            XCTAssertTrue(Thread.isMainThread)
            switch result {
            case .success(let items):
                XCTAssertEqual(items.count, 2)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1)
    }

    /// Ошибка обновления при toggleCompletion возвращается наружу
    func testToggleCompletionPropagatesUpdateError() async {
        let (repository, _, _) = await makeRepository()
        TodoRepository.debugFailure = .updateTodo(RepositoryTestError.failure)
        defer { TodoRepository.debugFailure = nil }

        let expectation = expectation(description: "toggle failure")
        repository.toggleCompletion(for: TodoItem(id: 1, title: "Any", details: nil, createdAt: Date(), isCompleted: false)) { result in
            XCTAssertTrue(Thread.isMainThread)
            switch result {
            case .success:
                XCTFail("Expected failure")
            case .failure(let error as RepositoryTestError):
                XCTAssertEqual(error, .failure)
            default:
                XCTFail("Unexpected error type")
            }
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1)
    }

    /// Если managed object не может построить модель, используется запасной конструктор
    func testCreateTodoUsesFallbackWhenEntityCannotFormModel() async throws {
        let stack = NilProducingCoreDataStack()
        let (repository, _, _) = await makeRepository(stack: stack)

        let item = try await createTodo(repository, title: "Fallback", details: "Details")

        XCTAssertEqual(item.title, "Fallback")
        XCTAssertEqual(item.details, "Details")
        XCTAssertTrue(item.id > 0)
    }

    /// Fallback используется и при обновлении, если asItem возвращает nil
    func testUpdateTodoUsesFallbackWhenEntityCannotFormModel() async throws {
        let stack = NilProducingCoreDataStack()
        let (repository, _, _) = await makeRepository(stack: stack)
        var item = try await createTodo(repository, title: "Original", details: "Body")
        item.title = "Updated"
        item.details = "Refined"
        item.isCompleted = true

        let result = try await updateTodo(repository, item: item)

        XCTAssertEqual(result.title, "Updated")
        XCTAssertEqual(result.details, "Refined")
        XCTAssertTrue(result.isCompleted)
    }

    /// Ошибка вычисления nextIdentifier приводит к failure результа
    func testCreateTodoWhenNextIdentifierFetchFailsReturnsError() async {
        let stack = FailingCoreDataStack(throwOnFetch: true)
        let (repository, _, _) = await makeRepository(stack: stack)

        do {
            _ = try await createTodo(repository, title: "Broken", details: nil)
            XCTFail("Expected createTodo to throw")
        } catch RepositoryTestError.failure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// При наличии данных completion loadInitial вызывается на главном потоке
    func testLoadInitialTodosWithExistingItemsCompletesOnMainThread() async {
        let stack = PreloadedCoreDataStack(seedCount: 2)
        let (repository, _, _) = await makeRepository(stack: stack)

        let completionExpectation = expectation(description: "count dispatch")
#if DEBUG
        let hookExpectation = expectation(description: "count hook")
        TodoRepository.countTodosHook = { count in
            XCTAssertEqual(count, 2)
            hookExpectation.fulfill()
        }
#endif
        repository.loadInitialTodos { result in
            XCTAssertTrue(Thread.isMainThread)
            switch result {
            case .success(let items):
                XCTAssertEqual(items.count, 2)
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            completionExpectation.fulfill()
        }

#if DEBUG
        await fulfillment(of: [completionExpectation, hookExpectation], timeout: 1)
        TodoRepository.countTodosHook = nil
#else
        await fulfillment(of: [completionExpectation], timeout: 1)
#endif
    }

    /// loadInitialTodos корректно работает при вызове из фонового потока
    func testLoadInitialTodosFromBackgroundThreadStillAccessesCountSafely() async {
        let stack = PreloadedCoreDataStack(seedCount: 3)
        let (repository, _, _) = await makeRepository(stack: stack)

        let completionExpectation = expectation(description: "completion")
#if DEBUG
        let hookExpectation = expectation(description: "count hook")
        TodoRepository.countTodosHook = { count in
            XCTAssertEqual(count, 3)
            hookExpectation.fulfill()
        }
        defer { TodoRepository.countTodosHook = nil }
#endif

        DispatchQueue(label: "background.count").async {
            repository.loadInitialTodos { result in
                XCTAssertTrue(Thread.isMainThread)
                if case .failure(let error) = result {
                    XCTFail("Unexpected error: \(error)")
                }
                completionExpectation.fulfill()
            }
        }

#if DEBUG
        await fulfillment(of: [completionExpectation, hookExpectation], timeout: 1)
#else
        await fulfillment(of: [completionExpectation], timeout: 1)
#endif
    }
}

// Вспомогательные методы для подготовки тестовых сценариев

/// Создаём репозиторий и уникальный suite UserDefaults для изоляции тестов
private func makeRepository(stack: CoreDataStackProtocol = TestCoreDataStack()) async -> (TodoRepository, MockTodoAPIClient, UserDefaults) {
    let apiClient = MockTodoAPIClient()
    let suite = "TodoRepositoryTests.\(UUID().uuidString)"
    let repository = await MainActor.run {
        TodoRepository(coreDataStack: stack, apiClient: apiClient, userDefaults: UserDefaults(suiteName: suite)!)
    }
    return (repository, apiClient, UserDefaults(suiteName: suite)!)
}

@MainActor
private func performOnMainActor<R>(
    _ body: @escaping (@escaping (Result<R, Error>) -> Void) -> Void
) async throws -> R {
    try await withCheckedThrowingContinuation { continuation in
        body { result in
            continuation.resume(with: result)
        }
    }
}

/// Загружаем стартовый набор задач, сохраняя семантику репозитория
@MainActor
private func loadInitialTodos(_ repository: TodoRepositoryProtocol) async throws -> [TodoItem] {
    try await performOnMainActor { completion in
        repository.loadInitialTodos(completion: completion)
    }
}

/// Достаём сохранённые задачи из Core Data
@MainActor
private func fetchTodos(_ repository: TodoRepositoryProtocol) async throws -> [TodoItem] {
    try await performOnMainActor { completion in
        repository.fetchTodos(completion: completion)
    }
}

/// Создаём тестовую задачу и возвращаем результат для дальнейших проверок
private func createTodo(
    _ repository: TodoRepositoryProtocol,
    title: String,
    details: String?
) async throws -> TodoItem {
    try await performOnMainActor { completion in
        repository.createTodo(title: title, details: details, completion: completion)
    }
}

/// Обновляем существующую задачу и возвращаем новую версию
private func updateTodo(
    _ repository: TodoRepositoryProtocol,
    item: TodoItem
) async throws -> TodoItem {
    try await performOnMainActor { completion in
        repository.updateTodo(item, completion: completion)
    }
}

/// Удаляем задачу из хранилища внутри теста
private func deleteTodo(
    _ repository: TodoRepositoryProtocol,
    item: TodoItem
) async throws {
    try await performOnMainActor { completion in
        repository.deleteTodo(item, completion: completion)
    }
}

/// Выполняем поиск по репозиторию и возвращаем найденные результаты
private func searchTodos(
    _ repository: TodoRepositoryProtocol,
    query: String
) async throws -> [TodoItem] {
    try await performOnMainActor { completion in
        repository.searchTodos(query: query, completion: completion)
    }
}

/// Переключаем статус задачи и возвращаем результат
private func toggleCompletion(
    _ repository: TodoRepositoryProtocol,
    item: TodoItem
) async throws -> TodoItem {
    try await performOnMainActor { completion in
        repository.toggleCompletion(for: item, completion: completion)
    }
}

// Заглушки и имитации ошибок для тестов репозитория

private final class FailingCoreDataStack: CoreDataStackProtocol {
    private let base: TestCoreDataStack
    private let throwOnSave: Bool
    private let throwOnFetch: Bool
    private let throwOnCount: Bool
    private let throwOnViewFetch: Bool

    init(
        throwOnSave: Bool = false,
        throwOnFetch: Bool = false,
        throwOnCount: Bool = false,
        throwOnViewFetch: Bool = false
    ) {
        self.base = TestCoreDataStack()
        self.throwOnSave = throwOnSave
        self.throwOnFetch = throwOnFetch
        self.throwOnCount = throwOnCount
        self.throwOnViewFetch = throwOnViewFetch
    }

    var viewContext: NSManagedObjectContext {
        guard throwOnViewFetch || throwOnCount else {
            return base.viewContext
        }
        let context = ThrowingContext(
            concurrencyType: .mainQueueConcurrencyType,
            throwsOnSave: false,
            throwsOnFetch: throwOnViewFetch,
            throwsOnCount: throwOnCount
        )
        context.persistentStoreCoordinator = base.container.persistentStoreCoordinator
        return context
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = ThrowingContext(
            concurrencyType: .privateQueueConcurrencyType,
            throwsOnSave: throwOnSave,
            throwsOnFetch: throwOnFetch,
            throwsOnCount: false
        )
        context.persistentStoreCoordinator = base.container.persistentStoreCoordinator
        context.perform {
            block(context)
        }
    }
}

private final class NilProducingCoreDataStack: CoreDataStackProtocol {
    private let base = TestCoreDataStack()

    var viewContext: NSManagedObjectContext {
        base.viewContext
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = NilProducingContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = base.container.persistentStoreCoordinator
        context.perform {
            block(context)
        }
    }
}

private final class NilProducingContext: NSManagedObjectContext, @unchecked Sendable {
    override func save() throws {
        let affected = insertedObjects
            .union(updatedObjects)
            .filter { $0.entity.name == "TodoEntity" }
        try super.save()
        affected.forEach { entity in
            entity.setValue(nil, forKey: "createdAt")
            entity.setValue(nil, forKey: "title")
        }
    }
}

private final class PreloadedCoreDataStack: CoreDataStackProtocol {
    private let base = TestCoreDataStack()

    init(seedCount: Int) {
        let context = base.viewContext
        let now = Date()
        for index in 0..<seedCount {
            let entity = TodoEntity(context: context)
            entity.id = Int64(index + 1)
            entity.title = "Seed #\(index + 1)"
            entity.details = "Details #\(index + 1)"
            entity.createdAt = now.addingTimeInterval(-Double(index))
            entity.isCompleted = false
        }
        try? context.save()
    }

    var viewContext: NSManagedObjectContext {
        base.viewContext
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        base.performBackgroundTask(block)
    }
}

private final class ThrowingContext: NSManagedObjectContext, @unchecked Sendable {
    private let throwsOnSave: Bool
    private let throwsOnFetch: Bool
    private let throwsOnCount: Bool

    init(
        concurrencyType ct: NSManagedObjectContextConcurrencyType,
        throwsOnSave: Bool,
        throwsOnFetch: Bool,
        throwsOnCount: Bool
    ) {
        self.throwsOnSave = throwsOnSave
        self.throwsOnFetch = throwsOnFetch
        self.throwsOnCount = throwsOnCount
        super.init(concurrencyType: ct)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func save() throws {
        if throwsOnSave {
            throw RepositoryTestError.failure
        }
        try super.save()
    }

    override func execute(_ request: NSPersistentStoreRequest) throws -> NSPersistentStoreResult {
        if throwsOnCount, request is NSFetchRequest<NSFetchRequestResult> {
            throw RepositoryTestError.failure
        }
        if throwsOnFetch, request is NSFetchRequest<NSFetchRequestResult> {
            throw RepositoryTestError.failure
        }
        return try super.execute(request)
    }
}
