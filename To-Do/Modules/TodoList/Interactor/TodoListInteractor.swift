//
//  TodoListInteractor.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation

/// Методы интерактора, с которыми общается презентер
protocol TodoListInteractorInput: AnyObject {
    func loadInitialTodos()
    func refreshTodos()
    func toggleCompletion(for item: TodoItem)
    func deleteTodo(_ item: TodoItem)
    func searchTodos(query: String)
}

/// Ответы интерактора для презентера
protocol TodoListInteractorOutput: AnyObject {
    func didUpdateTodos(_ items: [TodoItem])
    func didFail(with error: Error)
}

/// Реализация интерактора, общаемся с репозиторием
final class TodoListInteractor: TodoListInteractorInput {
    weak var output: TodoListInteractorOutput?

    private let repository: TodoRepositoryProtocol

    /// Передаём репозиторий через init
    init(repository: TodoRepositoryProtocol) {
        self.repository = repository
    }

    func loadInitialTodos() {
        repository.loadInitialTodos { [weak self] result in
            self?.handle(result: result)
        }
    }

    func refreshTodos() {
        repository.fetchTodos { [weak self] result in
            self?.handle(result: result)
        }
    }

    func toggleCompletion(for item: TodoItem) {
        repository.toggleCompletion(for: item) { [weak self] result in
            switch result {
            case .failure(let error):
                self?.output?.didFail(with: error)
            case .success:
                self?.refreshTodos()
            }
        }
    }

    func deleteTodo(_ item: TodoItem) {
        repository.deleteTodo(item) { [weak self] result in
            switch result {
            case .failure(let error):
                self?.output?.didFail(with: error)
            case .success:
                self?.refreshTodos()
            }
        }
    }

    func searchTodos(query: String) {
        repository.searchTodos(query: query) { [weak self] result in
            self?.handle(result: result)
        }
    }

    /// Простая обработка результата
    private func handle(result: Result<[TodoItem], Error>) {
        switch result {
        case .success(let items):
            output?.didUpdateTodos(items)
        case .failure(let error):
            output?.didFail(with: error)
        }
    }
}

