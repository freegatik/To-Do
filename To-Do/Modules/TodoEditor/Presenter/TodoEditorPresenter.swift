//
//  TodoEditorPresenter.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation

/// Методы обновления интерфейса редактора
@MainActor
protocol TodoEditorViewProtocol: AnyObject {
    func configure(with viewModel: TodoEditorViewModel)
    func showLoading(_ isLoading: Bool)
    func showError(message: String)
    func presentExitConfirmation(canSave: Bool, onSave: @escaping () -> Void, onDiscard: @escaping () -> Void)
}

/// Что может попросить вью у презентера
@MainActor
protocol TodoEditorPresenterProtocol: AnyObject {
    func viewDidLoad()
    func handleBackAction(title: String, details: String?, isCompleted: Bool)
}

/// Презентер подготавливает данные для UI и закрывает экран
@MainActor
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

    func handleBackAction(title: String, details: String?, isCompleted: Bool) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = details?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        switch mode {
        case .create:
            let hasAnyInput = !trimmedTitle.isEmpty || trimmedDetails != nil || isCompleted
            guard hasAnyInput else {
                cancelEditor()
                return
            }

            view?.presentExitConfirmation(
                canSave: !trimmedTitle.isEmpty,
                onSave: { [weak self] in
                    guard let self else { return }
                    self.save(title: trimmedTitle, details: trimmedDetails, isCompleted: isCompleted)
                },
                onDiscard: { [weak self] in
                    self?.cancelEditor()
                }
            )
            return
        case .edit:
            let original = currentTodo
            let originalDetails = original?.details?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            let hasChanges = trimmedTitle != original?.title
                || trimmedDetails != originalDetails
                || isCompleted != original?.isCompleted
            guard hasChanges else {
                cancelEditor()
                return
            }

            guard !trimmedTitle.isEmpty else {
                view?.presentExitConfirmation(
                    canSave: false,
                    onSave: { [weak self] in self?.view?.showError(message: "Введите название задачи.") },
                    onDiscard: { [weak self] in self?.cancelEditor() }
                )
                return
            }

            save(title: trimmedTitle, details: trimmedDetails, isCompleted: isCompleted)
        }
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
            createdAtText: todo.map { dateFormatter.string(from: $0.createdAt) }
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
    func save(title: String, details: String?, isCompleted: Bool) {
        view?.showLoading(true)
        interactor.saveTodo(title: title, details: details, isCompleted: isCompleted)
    }

    func cancelEditor() {
        output?.todoEditorDidFinish(with: .cancelled)
        router.dismiss()
    }

    nonisolated static func makeDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd/MM/yy"
        return formatter
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

