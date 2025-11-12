//
//  TestCoreDataStack.swift
//  To-DoTests
//
//  Created by Anton Solovev on 07.11.2025.
//

import CoreData
@testable import To_Do

/// In-memory Core Data стек для модульных тестов
final class TestCoreDataStack: CoreDataStackProtocol {
    let container: NSPersistentContainer

    init() {
        let possibleBundles: [Bundle] = [
            Bundle(for: TestCoreDataStack.self),
            Bundle.main
        ] + Bundle.allBundles

        guard
            let modelURL = possibleBundles.compactMap({ $0.url(forResource: "To_Do", withExtension: "momd") }).first,
            let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
        else {
            fatalError("Failed to load Core Data model")
        }

        container = NSPersistentContainer(name: "To_Do", managedObjectModel: managedObjectModel)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Unresolved error \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }
}

