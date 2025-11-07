//
//  TodoListPresenterTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation
import Testing
@testable import To_Do

@Suite("TodoListPresenter")
struct TodoListPresenterTests {
    @Test
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
    }

    @Test
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
}

// Mocks

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

private final class MockTodoListInteractor: TodoListInteractorInput {
    var didCallLoadInitial = false

    func loadInitialTodos() {
        didCallLoadInitial = true
    }

    func refreshTodos() { }

    func toggleCompletion(for item: TodoItem) { }

    func deleteTodo(_ item: TodoItem) { }

    func searchTodos(query: String) { }
}

private final class MockTodoListRouter: TodoListRouterProtocol {
    var lastMode: TodoEditorMode?

    func presentEditor(mode: TodoEditorMode, output: TodoEditorModuleOutput) {
        lastMode = mode
    }
}

private extension TodoEditorMode {
    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
}

private extension DateFormatter {
    static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter
    }()
}

