//
//  TodoListPresenterTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation
import Testing
@testable import To_Do

/// Проверяем поведение презентера списка задач
@Suite("TodoListPresenter")
struct TodoListPresenterTests {
    @Test
    /// При старте экрана презентер устанавливает заголовок и делает первоначальную загрузку
    func testViewDidLoadTriggersInitialLoad() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()

        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)
        presenter.viewDidLoad()

        #expect(view.navigationTitle == "Задачи")
        #expect(view.isLoadingShown)
        #expect(interactor.didCallLoadInitial)
    }

    @Test
    /// Презентер корректно преобразует доменные модели во view-модели и передает их в представление
    func testInteractorUpdateRendersViewModels() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        let date = Date(timeIntervalSince1970: 0)
        let items = [
            TodoItem(id: 1, title: "Task", details: "Details", createdAt: date, isCompleted: false)
        ]

        presenter.didUpdateTodos(items)

        let viewModel = view.lastViewModels?.first
        #expect(viewModel?.title == "Task")
        #expect(viewModel?.details == "Details")
        #expect(viewModel?.date == DateFormatter.shortFormatter.string(from: date))
        #expect(viewModel?.isCompleted == false)
        #expect(view.didDismissContextMenu == true)
    }

    @Test
    /// При выборе строки открывается экран редактора в режиме редактирования
    func testSelectionPushesEditor() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        let items = [
            TodoItem(id: 10, title: "Edit me", details: nil, createdAt: Date(), isCompleted: false)
        ]

        presenter.didUpdateTodos(items)
        presenter.didSelectItem(at: 0)

        #expect(router.lastMode?.isEdit == true)
    }

    @Test
    /// Долгое нажатие вызывает отображение контекстного меню с данными задачи
    func testLongPressShowsContextMenu() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        let item = TodoItem(id: 5, title: "Share", details: "Details", createdAt: Date(timeIntervalSince1970: 0), isCompleted: false)
        presenter.didUpdateTodos([item])

        presenter.didLongPressItem(at: 0)

        #expect(view.contextMenuModel?.title == "Share")
        #expect(view.contextMenuModel?.details == "Details")
    }

    @Test
    /// Обработка действия «поделиться» формирует текст и передает его во view
    func testShareActionSendsTextToView() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        let item = TodoItem(id: 7, title: "Share me", details: "Body", createdAt: Date(timeIntervalSince1970: 0), isCompleted: false)
        presenter.didUpdateTodos([item])
        presenter.didLongPressItem(at: 0)
        presenter.handleContextAction(.share)

        #expect(view.sharedText?.contains("Share me") == true)
        #expect(view.sharedText?.contains("Body") == true)
    }

    @Test
    /// Действие редактирования открывает редактор в режиме edit
    func testHandleContextActionEditPresentsEditor() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        let item = TodoItem(id: 11, title: "Edit", details: nil, createdAt: Date(), isCompleted: false)
        presenter.didUpdateTodos([item])
        presenter.didLongPressItem(at: 0)

        presenter.handleContextAction(.edit)

        #expect(router.lastMode?.isEdit == true)
    }

    @Test
    /// Удаление через контекстное меню вызывает соответствующий метод интерактора
    func testHandleContextActionDeleteInvokesInteractor() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        let item = TodoItem(id: 12, title: "Remove", details: nil, createdAt: Date(), isCompleted: false)
        presenter.didUpdateTodos([item])
        presenter.didLongPressItem(at: 0)

        presenter.handleContextAction(.delete)

        #expect(interactor.deletedItems.count == 1)
        #expect(interactor.deletedItems.first?.id == 12)
    }

    @Test
    /// После исчезновения меню actions игнорируются до следующего выделения
    func testContextMenuDidDisappearClearsHighlight() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        let item = TodoItem(id: 13, title: "Highlight", details: nil, createdAt: Date(), isCompleted: false)
        presenter.didUpdateTodos([item])
        presenter.didLongPressItem(at: 0)
        presenter.contextMenuDidDisappear()

        presenter.handleContextAction(.delete)

        #expect(interactor.deletedItems.isEmpty)
    }

    @Test
    /// didFail записывает ошибку во view и скрывает индикатор загрузки
    func testDidFailShowsErrorAndStopsLoading() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        presenter.didFail(with: DummyError.sample)

        #expect(view.lastErrorMessage == DummyError.sample.localizedDescription)
        #expect(view.isLoadingShown == false)
    }

    @Test
    /// Успешные сценарии редактора инициируют повторную загрузку задач
    func testEditorFinishRefreshesOnSuccess() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        let item = TodoItem(id: 1, title: "Any", details: nil, createdAt: Date(), isCompleted: false)
        presenter.todoEditorDidFinish(with: .created(item))
        presenter.todoEditorDidFinish(with: .updated(item))

        #expect(interactor.refreshCount == 2)
    }

    @Test
    /// Отмена в редакторе не вызывает обновления данных
    func testEditorFinishDoesNothingOnCancel() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        presenter.todoEditorDidFinish(with: .cancelled)

        #expect(interactor.refreshCount == 0)
    }

    @Test
    /// Обновление поискового запроса пробрасывается в интерактор
    func testUpdateSearchQueryForwardsToInteractor() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        presenter.updateSearchQuery("milk")

        #expect(interactor.searchQueries == ["milk"])
    }

    @Test
    /// Тоггл completion делегируется интерактору
    func testToggleCompletionDelegatesToInteractor() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        let item = TodoItem(id: 20, title: "Done?", details: nil, createdAt: Date(), isCompleted: false)
        presenter.didUpdateTodos([item])

        presenter.didToggleCompletion(at: 0)

        #expect(interactor.toggleItems.count == 1)
        #expect(interactor.toggleItems.first?.id == 20)
    }

    @Test
    /// Удаление элемента списка делегируется соответствующему методу интерактора
    func testDeleteItemDelegatesToInteractor() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        let item = TodoItem(id: 30, title: "Delete me", details: nil, createdAt: Date(), isCompleted: false)
        presenter.didUpdateTodos([item])

        presenter.didDeleteItem(at: 0)

        #expect(interactor.deletedItems.count == 1)
        #expect(interactor.deletedItems.first?.id == 30)
    }

    @Test
    /// Пустой список без поиска показывает дефолтное сообщение
    func testDidUpdateTodosEmptyShowsDefaultMessage() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        presenter.didUpdateTodos([])

        #expect(view.lastEmptyStateMessage == "Задачи отсутствуют.")
    }

    @Test
    /// После поиска пустой результат отображает сообщение про отсутствие совпадений
    func testDidUpdateTodosEmptyAfterSearchShowsQueryMessage() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        presenter.updateSearchQuery("milk")
        presenter.didUpdateTodos([])

        #expect(view.lastEmptyStateMessage == "Ничего не найдено по запросу.")
    }

    @Test
    /// Кнопка добавления открывает редактор в режиме создания
    func testDidTapAddPresentsCreateEditor() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        presenter.didTapAdd()

        #expect(router.lastMode?.isCreate == true)
    }

    @Test
    /// Текст для шаринга без описания не включает пустую строку
    func testShareActionWithoutDetailsOmitsEmptyLine() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        let date = Date(timeIntervalSince1970: 0)
        let item = TodoItem(id: 8, title: "Only title", details: nil, createdAt: date, isCompleted: false)
        presenter.didUpdateTodos([item])
        presenter.didLongPressItem(at: 0)
        presenter.handleContextAction(.share)

        let expected = ["Only title", DateFormatter.shortFormatter.string(from: date)].joined(separator: "\n")
        #expect(view.sharedText == expected)
    }

    @Test
    /// Пробельные детали обрезаются до nil при формировании view-модели
    func testViewModelTrimsDetailsWhitespace() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        let item = TodoItem(id: 3, title: "Task", details: "   ", createdAt: Date(timeIntervalSince1970: 0), isCompleted: false)
        presenter.didUpdateTodos([item])

        #expect(view.lastViewModels?.first?.details == nil)
    }

    @Test
    /// Pull-to-refresh запускает загрузку и включает индикатор
    func testDidPullToRefreshShowsLoadingAndRefreshes() {
        let view = MockTodoListView()
        let interactor = MockTodoListInteractor()
        let router = MockTodoListRouter()
        let presenter = TodoListPresenter(view: view, interactor: interactor, router: router)

        presenter.didPullToRefresh()

        #expect(view.isLoadingShown)
        #expect(interactor.refreshCount == 1)
    }
}

/// Тестовый double для вью, собирающий события от презентера

private final class MockTodoListView: TodoListViewProtocol {
    var navigationTitle: String?
    var isLoadingShown = false
    var lastViewModels: [TodoListItemViewModel]?
    var lastEmptyStateMessage: String?
    var lastErrorMessage: String?
    var contextMenuModel: TodoContextMenuViewModel?
    var didDismissContextMenu = false
    var sharedText: String?

    func setNavigationTitle(_ title: String) {
        navigationTitle = title
    }

    func showLoading(_ isLoading: Bool) {
        isLoadingShown = isLoading
    }

    func showTodos(_ viewModels: [TodoListItemViewModel]) {
        lastViewModels = viewModels
    }

    func showEmptyState(message: String) {
        lastEmptyStateMessage = message
    }

    func showError(message: String) {
        lastErrorMessage = message
    }

    func showContextMenu(for viewModel: TodoContextMenuViewModel) {
        contextMenuModel = viewModel
    }

    func dismissContextMenu() {
        didDismissContextMenu = true
    }

    func share(text: String) {
        sharedText = text
    }
}

/// Заглушка интерактора, запоминающая вызовы без реализации логики
private final class MockTodoListInteractor: TodoListInteractorInput {
    var didCallLoadInitial = false
    var deletedItems: [TodoItem] = []
    var toggleItems: [TodoItem] = []
    var refreshCount = 0
    var searchQueries: [String] = []

    func loadInitialTodos() {
        didCallLoadInitial = true
    }

    func refreshTodos() { refreshCount += 1 }

    func toggleCompletion(for item: TodoItem) { toggleItems.append(item) }

    func deleteTodo(_ item: TodoItem) { deletedItems.append(item) }

    func searchTodos(query: String) { searchQueries.append(query) }
}

/// Роутер-заменитель для проверки передаваемых режимов открытия редактора
private final class MockTodoListRouter: TodoListRouterProtocol {
    var lastMode: TodoEditorMode?

    func presentEditor(mode: TodoEditorMode, output: TodoEditorModuleOutput) {
        lastMode = mode
    }
}

/// Утилита для удобной проверки режима редактора в тестах
private extension TodoEditorMode {
    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }

    var isCreate: Bool {
        if case .create = self { return true }
        return false
    }
}

/// Общий форматтер дат для тестов презентера
private extension DateFormatter {
    static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter
    }()
}

/// Простейшая ошибка для проверки обработчиков
private enum DummyError: Error {
    case sample
}

