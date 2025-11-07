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

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Настраиваем контейнер и автослияние изменений
    init(container: NSPersistentContainer = NSPersistentContainer(name: "To_Do")) {
        self.container = container
        if ProcessInfo.processInfo.arguments.contains("--uitest") {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Unresolved Core Data error: \(error)")
            }
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

