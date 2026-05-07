//
//  TodoListInteractor.swift
//  To-Do
//
//  Created by Anton Solovev on 16.07.2023.
//

import Foundation

@MainActor
protocol TodoListInteractorInput: AnyObject {
    func loadInitialTodos()
    func refreshTodos()
    func toggleCompletion(for item: TodoItem)
    func deleteTodo(_ item: TodoItem)
    func searchTodos(query: String)
}

@MainActor
protocol TodoListInteractorOutput: AnyObject {
    func didUpdateTodos(_ items: [TodoItem])
    func didFail(with error: Error)
}

@MainActor
final class TodoListInteractor: TodoListInteractorInput {
    weak var output: TodoListInteractorOutput?

    private let repository: TodoRepositoryProtocol

    init(repository: TodoRepositoryProtocol) {
        self.repository = repository
    }

    func loadInitialTodos() {
        repository.loadInitialTodos { [weak self] result in
            Task { @MainActor [weak self] in
                self?.handle(result: result)
            }
        }
    }

    func refreshTodos() {
        repository.fetchTodos { [weak self] result in
            Task { @MainActor [weak self] in
                self?.handle(result: result)
            }
        }
    }

    func toggleCompletion(for item: TodoItem) {
        repository.toggleCompletion(for: item) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .failure(let error):
                    self.output?.didFail(with: error)
                case .success:
                    self.refreshTodos()
                }
            }
        }
    }

    func deleteTodo(_ item: TodoItem) {
        repository.deleteTodo(item) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .failure(let error):
                    self.output?.didFail(with: error)
                case .success:
                    self.refreshTodos()
                }
            }
        }
    }

    func searchTodos(query: String) {
        repository.searchTodos(query: query) { [weak self] result in
            Task { @MainActor [weak self] in
                self?.handle(result: result)
            }
        }
    }

    private func handle(result: Result<[TodoItem], Error>) {
        switch result {
        case .success(let items):
            output?.didUpdateTodos(items)
        case .failure(let error):
            output?.didFail(with: error)
        }
    }
}

