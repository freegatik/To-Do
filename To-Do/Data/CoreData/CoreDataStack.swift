//
//  CoreDataStack.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import CoreData

/// Простой протокол для работы с Core Data
protocol CoreDataStackProtocol {
    /// Основной контекст для UI
    var viewContext: NSManagedObjectContext { get }
    /// Выполняем задачи на фоне
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void)
}

/// Базовая реализация Core Data
final class CoreDataStack: CoreDataStackProtocol {
    /// Синглтон для приложения
    static let shared = CoreDataStack()

    let container: NSPersistentContainer
    private let errorHandler: ((Error) -> Void)?
    private let shouldAssertOnError: Bool
#if DEBUG
    static var assertionHandler: ((String) -> Void)?
    private static var defaultAssertionFailureAction: (String) -> Void { { assertionFailure($0) } }
    static var assertionFailureAction: (String) -> Void = defaultAssertionFailureAction
    static func failAssertion(_ message: String) {
        assertionFailureAction(message)
    }
    static func resetAssertionFailureAction() {
        assertionFailureAction = defaultAssertionFailureAction
    }
#else
    static func failAssertion(_ message: String) {
        assertionFailure(message)
    }
#endif

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Настраиваем контейнер и автослияние изменений
    init(
        container: NSPersistentContainer = NSPersistentContainer(name: "To_Do"),
        errorHandler: ((Error) -> Void)? = nil,
        shouldAssertOnError: Bool = true,
        loadPersistentStoresHandler: ((NSPersistentContainer, @escaping (NSPersistentStoreDescription, Error?) -> Void) -> Void)? = nil
    ) {
        self.container = container
        self.errorHandler = errorHandler
        self.shouldAssertOnError = shouldAssertOnError
        if ProcessInfo.processInfo.arguments.contains("--uitest") {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        let completion: (NSPersistentStoreDescription, Error?) -> Void = { _, error in
            if let error {
                errorHandler?(error)
                if shouldAssertOnError {
#if DEBUG
                    if let assertionHandler = CoreDataStack.assertionHandler {
                        assertionHandler("Unresolved Core Data error: \(error)")
                    } else {
                        CoreDataStack.failAssertion("Unresolved Core Data error: \(error)")
                    }
#else
                    CoreDataStack.failAssertion("Unresolved Core Data error: \(error)")
#endif
                }
            }
        }
        if let handler = loadPersistentStoresHandler {
            handler(container, completion)
        } else {
            container.loadPersistentStores(completionHandler: completion)
        }
    }

    /// Устанавливаем merge policy и выполняем блок
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            block(context)
        }
    }
}

