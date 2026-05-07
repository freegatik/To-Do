//
//  CoreDataStack.swift
//  To-Do
//
//  Created by Anton Solovev on 06.07.2023.
//

import CoreData

enum ToDoCoreDataModel {
    static let shared: NSManagedObjectModel = {
        let bundle = Bundle(for: CoreDataStack.self)
        guard let url = bundle.url(forResource: "To_Do", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Could not load To_Do Core Data model from \(bundle.bundlePath)")
        }
        return model
    }()
}

protocol CoreDataStackProtocol {
    var viewContext: NSManagedObjectContext { get }
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void)
}

final class CoreDataStack: CoreDataStackProtocol {
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

    init(
        container: NSPersistentContainer = NSPersistentContainer(name: "To_Do", managedObjectModel: ToDoCoreDataModel.shared),
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

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            block(context)
        }
    }
}

