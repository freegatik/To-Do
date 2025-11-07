//
//  TodoEditorInteractor.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation

/// Методы, которые вызывает презентер редактора
protocol TodoEditorInteractorInput: AnyObject {
    func loadInitialTodo()
    func saveTodo(title: String, details: String?, isCompleted: Bool)
}

/// Ответы из интерактора обратно презентеру
protocol TodoEditorInteractorOutput: AnyObject {
    func didLoad(todo: TodoItem?)
    func didSave(todo: TodoItem)
    func didFail(with error: Error)
}

/// Интерактор редактора: грузим данные и сохраняем
final class TodoEditorInteractor: TodoEditorInteractorInput {
    weak var output: TodoEditorInteractorOutput?

    private let repository: TodoRepositoryProtocol
    private let mode: TodoEditorMode

    /// Через init передаём репозиторий и режим
    init(repository: TodoRepositoryProtocol, mode: TodoEditorMode) {
        self.repository = repository
        self.mode = mode
    }

    func loadInitialTodo() {
        switch mode {
        case .create:
            output?.didLoad(todo: nil)
        case .edit(let todo):
            output?.didLoad(todo: todo)
        }
    }

    /// В режиме create добавляем, в режиме edit обновляем
    func saveTodo(title: String, details: String?, isCompleted: Bool) {
        switch mode {
        case .create:
            repository.createTodo(title: title, details: details) { [weak self] result in
                switch result {
                case .failure(let error):
                    self?.output?.didFail(with: error)
                case .success(let item):
                    self?.output?.didSave(todo: item)
                }
            }
        case .edit(let origin):
            var updated = origin
            updated.title = title
            updated.details = details
            updated.isCompleted = isCompleted

            repository.updateTodo(updated) { [weak self] result in
                switch result {
                case .failure(let error):
                    self?.output?.didFail(with: error)
                case .success(let item):
                    self?.output?.didSave(todo: item)
                }
            }
        }
    }
}

