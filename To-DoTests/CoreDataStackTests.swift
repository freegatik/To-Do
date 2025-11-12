//
//  CoreDataStackTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 11.11.2025.
//

import XCTest
import CoreData
@testable import To_Do

/// Проверяем обработку ошибок при инициализации Core Data стека
final class CoreDataStackTests: XCTestCase {
    /// При ошибке загрузки persistent store вызывается переданный error handler
    func testInitializerInvokesErrorHandlerWhenPersistentStoreFails() {
        var capturedError: Error?
        _ = CoreDataStack(container: FailingContainer(), errorHandler: { error in
            capturedError = error
        }, shouldAssertOnError: false)

        XCTAssertEqual((capturedError as NSError?)?.domain, "TestError")
    }

    /// Если включено shouldAssertOnError, срабатывает assertion handler
    func testInitializerWhenShouldAssertTriggersAssertionHandler() {
        let expectation = expectation(description: "assertion triggered")
        CoreDataStack.assertionHandler = { message in
            if message.contains("Unresolved Core Data error") {
                expectation.fulfill()
            }
        }
        _ = CoreDataStack(container: FailingContainer(), errorHandler: nil, shouldAssertOnError: true)
        wait(for: [expectation], timeout: 0.1)
        CoreDataStack.assertionHandler = nil
    }

    /// При отсутствии кастомного assertion handler используется запасной failure action
    func testInitializerWhenAssertionHandlerMissingUsesFailureAction() {
        let expectation = expectation(description: "assertion failure action triggered")
        CoreDataStack.assertionHandler = nil
        CoreDataStack.assertionFailureAction = { message in
            if message.contains("Unresolved Core Data error") {
                expectation.fulfill()
            }
        }

        _ = CoreDataStack(container: FailingContainer(), errorHandler: nil, shouldAssertOnError: true)

        wait(for: [expectation], timeout: 0.1)
        CoreDataStack.resetAssertionFailureAction()
    }
}

/// NSPersistentContainer, который намеренно падает при загрузке хранилища, чтобы тестировать обработчики
private final class FailingContainer: NSPersistentContainer, @unchecked Sendable {
    init() {
        let model = NSManagedObjectModel()
        super.init(name: "Failing", managedObjectModel: model)
        persistentStoreDescriptions = [NSPersistentStoreDescription()]
    }

    override func loadPersistentStores(completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> Void) {
        let description = persistentStoreDescriptions.first ?? NSPersistentStoreDescription()
        let error = NSError(domain: "TestError", code: 42)
        block(description, error)
    }
}

