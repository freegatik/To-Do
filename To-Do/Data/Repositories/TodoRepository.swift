//
//  TodoRepository.swift
//  To-Do
//
//  Created by Anton Solovev on 11.07.2023.
//

import Foundation
import CoreData

protocol TodoRepositoryProtocol {
    func loadInitialTodos(completion: @escaping (Result<[TodoItem], Error>) -> Void)
    func fetchTodos(completion: @escaping (Result<[TodoItem], Error>) -> Void)
    func createTodo(title: String, details: String?, completion: @escaping (Result<TodoItem, Error>) -> Void)
    func updateTodo(_ item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void)
    func toggleCompletion(for item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void)
    func deleteTodo(_ item: TodoItem, completion: @escaping (Result<Void, Error>) -> Void)
    func searchTodos(query: String, completion: @escaping (Result<[TodoItem], Error>) -> Void)
}

enum TodoRepositoryError: Error {
    case entityNotFound
    case invalidData
}

final class TodoRepository: TodoRepositoryProtocol {
    private enum Constants {
        static let initialLoadKey = "TodoRepository.initialLoad"
    }

#if DEBUG
    enum DebugFailure {
        case fetchTodos(Error)
        case createTodo(Error)
        case updateTodo(Error)
        case deleteTodo(Error)
        case searchTodos(Error)
    }

    static var debugFailure: DebugFailure?
    static var countTodosHook: ((Int) -> Void)?
    static var debugCountTodosError: Error?
    static var isUITestOverride: Bool?
#endif

    private let coreDataStack: CoreDataStackProtocol
    private let apiClient: TodoAPIClientProtocol
    private let userDefaults: UserDefaults

    init(
        coreDataStack: CoreDataStackProtocol,
        apiClient: TodoAPIClientProtocol,
        userDefaults: UserDefaults = .standard
    ) {
        self.coreDataStack = coreDataStack
        self.apiClient = apiClient
        self.userDefaults = userDefaults
    }

    func loadInitialTodos(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        let isUITestEnvironment: Bool
#if DEBUG
        if let override = TodoRepository.isUITestOverride {
            isUITestEnvironment = override
        } else {
            isUITestEnvironment = ProcessInfo.processInfo.arguments.contains("--uitest")
        }
#else
        isUITestEnvironment = ProcessInfo.processInfo.arguments.contains("--uitest")
#endif

        if isUITestEnvironment {
            userDefaults.set(true, forKey: Constants.initialLoadKey)
            fetchTodos(completion: completion)
            return
        }

        if userDefaults.bool(forKey: Constants.initialLoadKey) {
            fetchTodos(completion: completion)
            return
        }

        countTodos { count in
            guard count == 0 else {
                self.userDefaults.set(true, forKey: Constants.initialLoadKey)
                self.fetchTodos(completion: completion)
                return
            }

            self.apiClient.fetchTodos { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let dtos):
                    self.saveInitialTodos(dtos, completion: completion)
                }
            }
        }
    }

    func fetchTodos(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
#if DEBUG
        if case let .fetchTodos(error)? = TodoRepository.debugFailure {
            completion(.failure(error))
            return
        }
#endif
        coreDataStack.performBackgroundTask { context in
            do {
                let request = TodoEntity.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \TodoEntity.createdAt, ascending: false)]
                let entities = try context.fetch(request)
                let items = entities.compactMap { $0.asItem() }
                DispatchQueue.main.async {
                    completion(.success(items))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func createTodo(title: String, details: String?, completion: @escaping (Result<TodoItem, Error>) -> Void) {
#if DEBUG
        if case let .createTodo(error)? = TodoRepository.debugFailure {
            completion(.failure(error))
            return
        }
#endif
        coreDataStack.performBackgroundTask { context in
            do {
                let newId = try self.nextIdentifier(in: context)
                let entity = TodoEntity(context: context)
                entity.id = newId
                entity.title = title
                entity.details = details
                entity.createdAt = Date()
                entity.isCompleted = false

                try context.save()

                let item = entity.asItem() ?? TodoItem(
                    id: entity.id,
                    title: entity.title ?? title,
                    details: entity.details,
                    createdAt: entity.createdAt ?? Date(),
                    isCompleted: entity.isCompleted
                )
                DispatchQueue.main.async {
                    completion(.success(item))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func updateTodo(_ item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
#if DEBUG
        if case let .updateTodo(error)? = TodoRepository.debugFailure {
            completion(.failure(error))
            return
        }
#endif
        coreDataStack.performBackgroundTask { context in
            do {
                guard let entity = try self.fetchEntity(with: item.id, in: context) else {
                    throw TodoRepositoryError.entityNotFound
                }
                entity.title = item.title
                entity.details = item.details
                entity.isCompleted = item.isCompleted

                try context.save()

                let updated = entity.asItem() ?? item
                DispatchQueue.main.async {
                    completion(.success(updated))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func toggleCompletion(for item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        var updated = item
        updated.isCompleted.toggle()
        updateTodo(updated, completion: completion)
    }

    func deleteTodo(_ item: TodoItem, completion: @escaping (Result<Void, Error>) -> Void) {
#if DEBUG
        if case let .deleteTodo(error)? = TodoRepository.debugFailure {
            completion(.failure(error))
            return
        }
#endif
        coreDataStack.performBackgroundTask { context in
            do {
                guard let entity = try self.fetchEntity(with: item.id, in: context) else {
                    throw TodoRepositoryError.entityNotFound
                }
                context.delete(entity)
                try context.save()
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func searchTodos(query: String, completion: @escaping (Result<[TodoItem], Error>) -> Void) {
#if DEBUG
        if case let .searchTodos(error)? = TodoRepository.debugFailure {
            completion(.failure(error))
            return
        }
#endif
        coreDataStack.performBackgroundTask { context in
            do {
                let request = TodoEntity.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \TodoEntity.createdAt, ascending: false)]
                let entities = try context.fetch(request)
                let items = entities.compactMap { $0.asItem() }
                let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
                let filtered: [TodoItem]
                if trimmedQuery.isEmpty {
                    filtered = items
                } else {
                    let normalizedQuery = trimmedQuery.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    filtered = items.filter { item in
                        let normalizedTitle = item.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                        if normalizedTitle.contains(normalizedQuery) {
                            return true
                        }
                        if let details = item.details?.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current),
                           details.contains(normalizedQuery) {
                            return true
                        }
                        return false
                    }
                }
                DispatchQueue.main.async {
                    completion(.success(filtered))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func saveInitialTodos(
        _ dtos: [TodoDTO],
        completion: @escaping (Result<[TodoItem], Error>) -> Void
    ) {
        coreDataStack.performBackgroundTask { context in
            do {
                let baseDate = Date()
                for (index, dto) in dtos.enumerated() {
                    let entity = TodoEntity(context: context)
                    let createdAt = baseDate.addingTimeInterval(-Double(index))
                    let item = TodoItem(dto: dto, createdAt: createdAt)
                    entity.update(with: item)
                }

                try context.save()
                self.userDefaults.set(true, forKey: Constants.initialLoadKey)

                let request = TodoEntity.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \TodoEntity.createdAt, ascending: false)]
                let entities = try context.fetch(request)
                let items = entities.compactMap { $0.asItem() }

                DispatchQueue.main.async {
                    completion(.success(items))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private func fetchEntity(with id: Int64, in context: NSManagedObjectContext) throws -> TodoEntity? {
        let request = TodoEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %lld", id)
        let results = try context.fetch(request)
        return results.first
    }

    private func nextIdentifier(in context: NSManagedObjectContext) throws -> Int64 {
        let request = TodoEntity.fetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TodoEntity.id, ascending: false)]

        let entities = try context.fetch(request)
        guard let lastEntity = entities.first else {
            return 1
        }
        return lastEntity.id + 1
    }

    private func countTodos(completion: @escaping (Int) -> Void) {
        let count = countTodosValue()
#if DEBUG
        TodoRepository.countTodosHook?(count)
#endif
        completion(count)
    }

    private func countTodosValue() -> Int {
        let context = coreDataStack.viewContext
        let request = TodoEntity.fetchRequest()
        var result = 0
        context.performAndWait {
#if DEBUG
            let forcedError = TodoRepository.debugCountTodosError
            TodoRepository.debugCountTodosError = nil
#else
            let forcedError: Error? = nil
#endif
            do {
                if let forcedError {
                    throw forcedError
                }
                result = try context.count(for: request)
            } catch {
                result = 0
            }
        }
        return result
    }
}

