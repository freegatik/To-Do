//
//  TestCoreDataStack.swift
//  To-DoTests
//
//  Created by Anton Solovev on 07.11.2025.
//

import CoreData
@testable import To_Do

final class TestCoreDataStack: CoreDataStackProtocol {
    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "To_Do")
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

