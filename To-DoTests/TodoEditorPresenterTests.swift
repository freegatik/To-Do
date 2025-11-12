//
//  TodoEditorPresenterTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 11.11.2025.
//

import XCTest
@testable import To_Do

/// Проверяем обработку сценариев презентером редактора задач
@MainActor
final class TodoEditorPresenterTests: XCTestCase {
    private static var retentionBag: [TodoEditorPresenter] = []
    private var view: MockView!
    private var interactor: MockInteractor!
    private var router: MockRouter!
    private var output: MockModuleOutput!
    private var dateFormatter: DateFormatter!

    override func setUp() {
        super.setUp()
        view = MockView()
        interactor = MockInteractor()
        router = MockRouter()
        output = MockModuleOutput()
        dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy/MM/dd"
    }

    override func tearDown() {
        dateFormatter = nil
        output = nil
        router = nil
        interactor = nil
        view = nil
        super.tearDown()
    }

    /// При загрузке вью презентер запрашивает из интерактора стартовые данные
    func testViewDidLoadRequestsInitialTodo() {
        let sut = makePresenter(mode: .create)

        sut.viewDidLoad()

        XCTAssertEqual(interactor.loadInitialTodoCallCount, 1)
    }

    /// В режиме создания без ввода происходит закрытие без сохранения
    func testHandleBackActionCreateWithoutInputCancelsEditor() {
        let sut = makePresenter(mode: .create)

        sut.handleBackAction(title: "   ", details: nil, isCompleted: false)

        XCTAssertEqual(router.dismissCallCount, 1)
        XCTAssertTrue(output.receivedResults.last?.isCancelled ?? false)
        XCTAssertTrue(view.exitConfirmationInvocations.isEmpty)
    }

    /// Если пользователь ввёл данные, показываем подтверждение выхода с опцией сохранения
    func testHandleBackActionCreateWithInputPresentsExitConfirmation() {
        let sut = makePresenter(mode: .create)
        let expectationSave = expectation(description: "saveTodo called")
        interactor.onSave = { title, details, isCompleted in
            XCTAssertEqual(title, "Title")
            XCTAssertEqual(details, "Note")
            XCTAssertTrue(isCompleted)
            expectationSave.fulfill()
        }

        sut.handleBackAction(title: " Title ", details: "  Note ", isCompleted: true)

        guard let confirmation = view.exitConfirmationInvocations.first else {
            XCTFail("Expected exit confirmation to be presented")
            return
        }
        XCTAssertTrue(confirmation.canSave)

        confirmation.onSave()

        wait(for: [expectationSave], timeout: 0.1)
        XCTAssertTrue(view.loadingStates.contains(true))

        confirmation.onDiscard()

        XCTAssertEqual(router.dismissCallCount, 1)
        XCTAssertTrue(output.receivedResults.last?.isCancelled ?? false)
    }

    /// В режиме редактирования пустой заголовок вызывает ошибку валидации
    func testHandleBackActionEditWithEmptyTitleShowsError() {
        let original = makeTodo(id: 1, title: "Initial", details: "Desc", isCompleted: false)
        let sut = makePresenter(mode: .edit(original))
        sut.didLoad(todo: original)

        sut.handleBackAction(title: "   ", details: "Desc", isCompleted: true)

        XCTAssertEqual(view.errorMessages.last, "Введите название задачи.")
        XCTAssertEqual(router.dismissCallCount, 0)
    }

    /// При отсутствии изменений редактор закрывается без дополнительных действий
    func testHandleBackActionEditWithoutChangesCancelsEditor() {
        let original = makeTodo(id: 2, title: "Initial", details: "Desc", isCompleted: false)
        let sut = makePresenter(mode: .edit(original))
        sut.didLoad(todo: original)

        sut.handleBackAction(title: "Initial", details: "Desc", isCompleted: false)

        XCTAssertEqual(router.dismissCallCount, 1)
        XCTAssertTrue(output.receivedResults.last?.isCancelled ?? false)
    }

    /// Изменения в задаче запускают сохранение через интерактор
    func testHandleBackActionEditWithChangesSavesTodo() {
        let original = makeTodo(id: 3, title: "Initial", details: "Desc", isCompleted: false)
        let sut = makePresenter(mode: .edit(original))
        sut.didLoad(todo: original)
        let expectationSave = expectation(description: "saveTodo called")
        interactor.onSave = { title, details, isCompleted in
            XCTAssertEqual(title, "Updated")
            XCTAssertEqual(details, "Updated details")
            XCTAssertTrue(isCompleted)
            expectationSave.fulfill()
        }

        sut.handleBackAction(title: " Updated ", details: " Updated details ", isCompleted: true)

        wait(for: [expectationSave], timeout: 0.1)
        XCTAssertTrue(view.loadingStates.contains(true))
        XCTAssertEqual(router.dismissCallCount, 0)
    }

    /// Ответ интерактора приводит к настройке вью корректной моделью
    func testDidLoadConfiguresViewWithTodo() {
        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
        let todo = makeTodo(id: 4, title: "Existing", details: "Details", isCompleted: false, createdAt: originalDate)
        let sut = makePresenter(mode: .create)

        sut.didLoad(todo: todo)

        let viewModel = view.configureInvocations.last
        XCTAssertEqual(viewModel?.title, "Existing")
        XCTAssertEqual(viewModel?.details, "Details")
        XCTAssertEqual(viewModel?.createdAtText, dateFormatter.string(from: originalDate))
    }

    /// Сохранение в режиме создания уведомляет координатор и закрывает экран
    func testDidSaveInCreateModeNotifiesOutputAndDismisses() {
        let sut = makePresenter(mode: .create)
        let newTodo = makeTodo(id: 5, title: "New", details: nil, isCompleted: false)

        sut.didSave(todo: newTodo)

        XCTAssertTrue(view.loadingStates.contains(false))
        XCTAssertTrue(output.receivedResults.last?.matchesCreated(todo: newTodo) ?? false)
        XCTAssertEqual(router.dismissCallCount, 1)
    }

    /// В режиме редактирования в output уходит updated результат
    func testDidSaveInEditModeDeliversUpdatedResult() {
        let original = makeTodo(id: 6, title: "Old", details: nil, isCompleted: false)
        let sut = makePresenter(mode: .edit(original))
        let updated = makeTodo(id: 6, title: "Updated", details: nil, isCompleted: true)

        sut.didSave(todo: updated)

        XCTAssertTrue(output.receivedResults.last?.matchesUpdated(todo: updated) ?? false)
        XCTAssertEqual(router.dismissCallCount, 1)
    }

    /// Ошибка интерактора скрывает лоадер и показывает сообщение
    func testDidFailStopsLoadingAndShowsError() {
        let sut = makePresenter(mode: .create)
        let error = NSError(domain: "Tests", code: 42, userInfo: [NSLocalizedDescriptionKey: "Failure"])

        sut.didFail(with: error)

        let hasLoadingFalse = view.loadingStates.contains(false)
        let lastError = view.errorMessages.last
        interactor.output = nil
        XCTAssertTrue(hasLoadingFalse)
        XCTAssertEqual(lastError, "Failure")
    }

    /// Заглушка вью корректно сохраняет ошибку без падения
    func testMockViewShowErrorDoesNotCrash() {
        view.showError(message: "Test message")
        XCTAssertEqual(view.errorMessages.last, "Test message")
    }

    // Вспомогательные методы и заглушки презентера

    /// Формируем презентер с заранее подготовленными заглушками
    private func makePresenter(mode: TodoEditorMode) -> TodoEditorPresenter {
        let presenter = TodoEditorPresenter(
            view: view,
            interactor: interactor,
            router: router,
            output: output,
            mode: mode,
            dateFormatter: dateFormatter
        )
        interactor.output = presenter
        Self.retentionBag.append(presenter)
        return presenter
    }
}

/// Заглушка представления редактора, собирающая события для проверки
@MainActor
private final class MockView: TodoEditorViewProtocol {
    var configureInvocations: [TodoEditorViewModel] = []
    var loadingStates: [Bool] = []
    var errorMessages: [String] = []
    var exitConfirmationInvocations: [(canSave: Bool, onSave: () -> Void, onDiscard: () -> Void)] = []

    func configure(with viewModel: TodoEditorViewModel) {
        configureInvocations.append(viewModel)
    }

    func showLoading(_ isLoading: Bool) {
        loadingStates.append(isLoading)
    }

    func showError(message: String) {
        errorMessages.append(message)
    }

    func presentExitConfirmation(
        canSave: Bool,
        onSave: @escaping () -> Void,
        onDiscard: @escaping () -> Void
    ) {
        exitConfirmationInvocations.append((canSave, onSave, onDiscard))
    }
}

/// Интерактор-заглушка, фиксирующий вызовы презентера
@MainActor
private final class MockInteractor: TodoEditorInteractorInput {
    weak var output: TodoEditorInteractorOutput?

    private(set) var loadInitialTodoCallCount = 0
    private(set) var saveInvocations: [(String, String?, Bool)] = []
    var onSave: ((String, String?, Bool) -> Void)?

    func loadInitialTodo() {
        loadInitialTodoCallCount += 1
    }

    func saveTodo(title: String, details: String?, isCompleted: Bool) {
        saveInvocations.append((title, details, isCompleted))
        onSave?(title, details, isCompleted)
    }
}

/// Роутер-заглушка, считающая количество закрытий
@MainActor
private final class MockRouter: TodoEditorRouterProtocol {
    private(set) var dismissCallCount = 0

    func dismiss() {
        dismissCallCount += 1
    }
}
 
/// Output-заглушка для отслеживания результатов работы модуля
@MainActor
private final class MockModuleOutput: TodoEditorModuleOutput {
    private(set) var receivedResults: [TodoEditorResult] = []

    func todoEditorDidFinish(with result: TodoEditorResult) {
        receivedResults.append(result)
    }
}

/// Утилита для создания TodoItem в тестах
private func makeTodo(
    id: Int64,
    title: String,
    details: String?,
    isCompleted: Bool,
    createdAt: Date = Date()
) -> TodoItem {
    TodoItem(id: id, title: title, details: details, createdAt: createdAt, isCompleted: isCompleted)
}

/// Удобные проверки результатов работы редактора
private extension TodoEditorResult {
    var isCancelled: Bool {
        if case .cancelled = self { return true }
        return false
    }

    func matchesCreated(todo: TodoItem) -> Bool {
        if case let .created(created) = self {
            return created.id == todo.id
                && created.title == todo.title
                && created.details == todo.details
                && created.isCompleted == todo.isCompleted
        }
        return false
    }

    func matchesUpdated(todo: TodoItem) -> Bool {
        if case let .updated(updated) = self {
            return updated.id == todo.id
                && updated.title == todo.title
                && updated.details == todo.details
                && updated.isCompleted == todo.isCompleted
        }
        return false
    }
}

