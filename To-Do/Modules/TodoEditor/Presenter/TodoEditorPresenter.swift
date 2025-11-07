//
//  TodoEditorPresenter.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation

/// Методы обновления интерфейса редактора
protocol TodoEditorViewProtocol: AnyObject {
    func configure(with viewModel: TodoEditorViewModel)
    func showLoading(_ isLoading: Bool)
    func showError(message: String)
}

/// Что может попросить вью у презентера
protocol TodoEditorPresenterProtocol: AnyObject {
    func viewDidLoad()
    func didTapSave(title: String, details: String?, isCompleted: Bool)
    func didTapCancel()
}

/// Презентер подготавливает данные для UI и закрывает экран
final class TodoEditorPresenter: TodoEditorPresenterProtocol {
    weak var view: TodoEditorViewProtocol?

    private let interactor: TodoEditorInteractorInput
    private let router: TodoEditorRouterProtocol
    private weak var output: TodoEditorModuleOutput?
    private let mode: TodoEditorMode
    private let dateFormatter: DateFormatter

    private var currentTodo: TodoItem?

    /// Передаём все зависимости и форматтер
    init(
        view: TodoEditorViewProtocol,
        interactor: TodoEditorInteractorInput,
        router: TodoEditorRouterProtocol,
        output: TodoEditorModuleOutput?,
        mode: TodoEditorMode,
        dateFormatter: DateFormatter = TodoEditorPresenter.makeDateFormatter()
    ) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.output = output
        self.mode = mode
        self.dateFormatter = dateFormatter
    }

    func viewDidLoad() {
        interactor.loadInitialTodo()
    }

    func didTapSave(title: String, details: String?, isCompleted: Bool) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validate(title: trimmedTitle) else {
            view?.showError(message: "Введите название задачи.")
            return
        }

        view?.showLoading(true)
        let trimmedDetails = details?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        interactor.saveTodo(title: trimmedTitle, details: trimmedDetails, isCompleted: isCompleted)
    }

    func didTapCancel() {
        output?.todoEditorDidFinish(with: .cancelled)
        router.dismiss()
    }
}

/// Слушаем ответы интерактора и формируем результат
extension TodoEditorPresenter: TodoEditorInteractorOutput {
    func didLoad(todo: TodoItem?) {
        currentTodo = todo
        let viewModel = TodoEditorViewModel(
            title: todo?.title ?? "",
            details: todo?.details ?? "",
            isCompleted: todo?.isCompleted ?? false,
            createdAtText: todo.map { "Создано \(dateFormatter.string(from: $0.createdAt))" },
            actionButtonTitle: mode.actionTitle
        )
        view?.configure(with: viewModel)
    }

    func didSave(todo: TodoItem) {
        view?.showLoading(false)
        currentTodo = todo
        let result: TodoEditorResult = {
            switch mode {
            case .create:
                return .created(todo)
            case .edit:
                return .updated(todo)
            }
        }()
        output?.todoEditorDidFinish(with: result)
        router.dismiss()
    }

    func didFail(with error: Error) {
        view?.showLoading(false)
        view?.showError(message: error.localizedDescription)
    }
}

private extension TodoEditorPresenter {
    func validate(title: String) -> Bool {
        !title.isEmpty
    }

    static func makeDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

private extension TodoEditorMode {
    var actionTitle: String {
        switch self {
        case .create:
            return "Создать"
        case .edit:
            return "Сохранить"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

