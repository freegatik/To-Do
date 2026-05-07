//
//  TodoEditorInteractor.swift
//  To-Do
//
//  Created by Anton Solovev on 24.07.2023.
//

import Foundation

protocol TodoEditorInteractorInput: AnyObject {
    func loadInitialTodo()
    func saveTodo(title: String, details: String?, isCompleted: Bool)
}

@MainActor
protocol TodoEditorInteractorOutput: AnyObject {
    func didLoad(todo: TodoItem?)
    func didSave(todo: TodoItem)
    func didFail(with error: Error)
}

final class TodoEditorInteractor: TodoEditorInteractorInput {
    weak var output: TodoEditorInteractorOutput?

    private let repository: TodoRepositoryProtocol
    private let mode: TodoEditorMode

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

