//
//  TodoListPresenter.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation

/// Что должно уметь отображение списка
protocol TodoListViewProtocol: AnyObject {
    func setNavigationTitle(_ title: String)
    func showLoading(_ isLoading: Bool)
    func showTodos(_ viewModels: [TodoListItemViewModel])
    func showEmptyState(message: String)
    func showError(message: String)
    func showContextMenu(for viewModel: TodoContextMenuViewModel)
    func dismissContextMenu()
    func share(text: String)
}

/// Интерфейс презентера для экрана списка
protocol TodoListPresenterProtocol: AnyObject {
    func viewDidLoad()
    func didTapAdd()
    func didPullToRefresh()
    func didSelectItem(at index: Int)
    func didToggleCompletion(at index: Int)
    func didDeleteItem(at index: Int)
    func updateSearchQuery(_ query: String)
    func didLongPressItem(at index: Int)
    func handleContextAction(_ action: TodoContextAction)
    func contextMenuDidDisappear()
}

/// Презентер держит состояние списка и навигацию
final class TodoListPresenter: TodoListPresenterProtocol {
    weak var view: TodoListViewProtocol?

    private let interactor: TodoListInteractorInput
    private let router: TodoListRouterProtocol
    private let dateFormatter: DateFormatter

    private var items: [TodoItem] = []
    private var currentQuery: String = ""
    private var highlightedItem: TodoItem?

    /// Передаём зависимостей и форматтер
    init(
        view: TodoListViewProtocol,
        interactor: TodoListInteractorInput,
        router: TodoListRouterProtocol,
        dateFormatter: DateFormatter = TodoListPresenter.makeDateFormatter()
    ) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.dateFormatter = dateFormatter
    }

    func viewDidLoad() {
        view?.setNavigationTitle("Задачи")
        view?.showLoading(true)
        interactor.loadInitialTodos()
    }

    func didTapAdd() {
        router.presentEditor(mode: .create, output: self)
    }

    func didPullToRefresh() {
        view?.showLoading(true)
        interactor.refreshTodos()
    }

    func didSelectItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        router.presentEditor(mode: .edit(items[index]), output: self)
    }

    func didToggleCompletion(at index: Int) {
        guard items.indices.contains(index) else { return }
        interactor.toggleCompletion(for: items[index])
    }

    func didDeleteItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        interactor.deleteTodo(items[index])
    }

    func updateSearchQuery(_ query: String) {
        currentQuery = query
        interactor.searchTodos(query: query)
    }

    func didLongPressItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        let item = items[index]
        highlightedItem = item
        view?.showContextMenu(for: makeContextMenuViewModel(from: item))
    }

    func handleContextAction(_ action: TodoContextAction) {
        guard let item = highlightedItem else { return }
        switch action {
        case .edit:
            router.presentEditor(mode: .edit(item), output: self)
        case .share:
            view?.share(text: shareText(for: item))
        case .delete:
            interactor.deleteTodo(item)
        }
    }

    func contextMenuDidDisappear() {
        highlightedItem = nil
    }

    /// Конвертируем доменные модели в view‑модели
    private func handle(items: [TodoItem]) {
        self.items = items
        let viewModels = items.map(makeViewModel)
        if viewModels.isEmpty {
            let message = currentQuery.isEmpty ? "Задачи отсутствуют." : "Ничего не найдено по запросу."
            view?.showEmptyState(message: message)
        } else {
            view?.showTodos(viewModels)
        }
    }

    private func makeViewModel(from item: TodoItem) -> TodoListItemViewModel {
        TodoListItemViewModel(
            id: item.id,
            title: item.title,
            details: item.details?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            date: dateFormatter.string(from: item.createdAt),
            isCompleted: item.isCompleted
        )
    }
}

/// Получаем данные от интерактора
extension TodoListPresenter: TodoListInteractorOutput {
    func didUpdateTodos(_ items: [TodoItem]) {
        view?.showLoading(false)
        view?.dismissContextMenu()
        handle(items: items)
    }

    func didFail(with error: Error) {
        view?.showLoading(false)
        view?.showError(message: error.localizedDescription)
    }
}

/// Обрабатываем результат работы редактора
extension TodoListPresenter: TodoEditorModuleOutput {
    func todoEditorDidFinish(with result: TodoEditorResult) {
        switch result {
        case .created, .updated:
            interactor.refreshTodos()
        case .cancelled:
            break
        }
    }
}

private extension TodoListPresenter {
    private static func makeDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter
    }

    private func makeContextMenuViewModel(from item: TodoItem) -> TodoContextMenuViewModel {
        TodoContextMenuViewModel(
            title: item.title,
            details: item.details?.nilIfEmpty,
            date: dateFormatter.string(from: item.createdAt),
            isCompleted: item.isCompleted
        )
    }

    private func shareText(for item: TodoItem) -> String {
        var lines = [item.title]
        if let details = item.details?.nilIfEmpty {
            lines.append(details)
        }
        lines.append(dateFormatter.string(from: item.createdAt))
        return lines.joined(separator: "\n")
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

