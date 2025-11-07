//
//  TodoRepository.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import Foundation
import CoreData

/// Простой протокол для работы с задачами
protocol TodoRepositoryProtocol {
    /// Тянем данные с сервера при первом запуске
    func loadInitialTodos(completion: @escaping (Result<[TodoItem], Error>) -> Void)
    /// Получаем задачи из Core Data
    func fetchTodos(completion: @escaping (Result<[TodoItem], Error>) -> Void)
    /// Создаём новую запись
    func createTodo(title: String, details: String?, completion: @escaping (Result<TodoItem, Error>) -> Void)
    /// Обновляем существующую запись
    func updateTodo(_ item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void)
    /// Меняем статус выполнено/нет
    func toggleCompletion(for item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void)
    /// Удаляем задачу
    func deleteTodo(_ item: TodoItem, completion: @escaping (Result<Void, Error>) -> Void)
    /// Ищем по названию или описанию
    func searchTodos(query: String, completion: @escaping (Result<[TodoItem], Error>) -> Void)
}

/// Возможные ошибки репозитория
enum TodoRepositoryError: Error {
    case entityNotFound
    case invalidData
}

/// Реализация репозитория поверх Core Data и сети
final class TodoRepository: TodoRepositoryProtocol {
    private enum Constants {
        static let initialLoadKey = "TodoRepository.initialLoad"
    }

    private let coreDataStack: CoreDataStackProtocol
    private let apiClient: TodoAPIClientProtocol
    private let userDefaults: UserDefaults

    /// Передаём зависимости через init
    init(
        coreDataStack: CoreDataStackProtocol,
        apiClient: TodoAPIClientProtocol,
        userDefaults: UserDefaults = .standard
    ) {
        self.coreDataStack = coreDataStack
        self.apiClient = apiClient
        self.userDefaults = userDefaults
    }

    /// Проверяем, нужно ли грузить стартовые данные из API
    func loadInitialTodos(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        if ProcessInfo.processInfo.arguments.contains("--uitest") {
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

    /// Берём задачи из Core Data по дате
    func fetchTodos(completion: @escaping (Result<[TodoItem], Error>) -> Void) {
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

    /// Создаём новую сущность и возвращаем её на главный поток
    func createTodo(title: String, details: String?, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        coreDataStack.performBackgroundTask { context in
            do {
                let entity = TodoEntity(context: context)
                entity.id = try self.nextIdentifier(in: context)
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

    /// Обновляем выбранную задачу, если она ещё есть
    func updateTodo(_ item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
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

    /// Переключаем флаг выполнено и переиспользуем update
    func toggleCompletion(for item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {
        var updated = item
        updated.isCompleted.toggle()
        updateTodo(updated, completion: completion)
    }

    /// Удаляем сущность и отвечаем в главном потоке
    func deleteTodo(_ item: TodoItem, completion: @escaping (Result<Void, Error>) -> Void) {
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

    /// Фильтруем задачи без блокировки UI
    func searchTodos(query: String, completion: @escaping (Result<[TodoItem], Error>) -> Void) {
        coreDataStack.performBackgroundTask { context in
            do {
                let request = TodoEntity.fetchRequest()
                if !query.isEmpty {
                    request.predicate = NSPredicate(
                        format: "title CONTAINS[cd] %@ OR details CONTAINS[cd] %@",
                        query,
                        query
                    )
                }
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

    /// Сохраняем ответ сервера в Core Data и ставим флаг загрузки
    private func saveInitialTodos(
        _ dtos: [TodoDTO],
        completion: @escaping (Result<[TodoItem], Error>) -> Void
    ) {
        coreDataStack.performBackgroundTask { context in
            do {
                for dto in dtos {
                    let entity = TodoEntity(context: context)
                    let item = TodoItem(dto: dto)
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

    /// Находим сущность по id
    private func fetchEntity(with id: Int64, in context: NSManagedObjectContext) throws -> TodoEntity? {
        let request = TodoEntity.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %lld", id)
        let results = try context.fetch(request)
        return results.first
    }

    /// Считаем следующий id на основе максимального
    private func nextIdentifier(in context: NSManagedObjectContext) throws -> Int64 {
        let request = NSFetchRequest<NSDictionary>(entityName: "TodoEntity")
        request.resultType = .dictionaryResultType
        let expressionDescription = NSExpressionDescription()
        expressionDescription.name = "maxId"
        expressionDescription.expression = NSExpression(forFunction: "max:", arguments: [NSExpression(forKeyPath: "id")])
        expressionDescription.expressionResultType = .integer64AttributeType
        request.propertiesToFetch = [expressionDescription]

        let result = try context.fetch(request)
        let maxId = result.first?["maxId"] as? Int64 ?? 0
        return maxId + 1
    }

    /// Считаем количество задач, чтобы понять, нужно ли импортировать
    private func countTodos(completion: @escaping (Int) -> Void) {
        coreDataStack.performBackgroundTask { context in
            let request = TodoEntity.fetchRequest()
            let count = (try? context.count(for: request)) ?? 0
            DispatchQueue.main.async {
                completion(count)
            }
        }
    }
}

