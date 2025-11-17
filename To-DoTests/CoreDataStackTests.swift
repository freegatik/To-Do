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
    private static var retentionBag: [CoreDataStack] = []
    /// При ошибке загрузки persistent store вызывается переданный error handler
    func testInitializerInvokesErrorHandlerWhenPersistentStoreFails() {
        let expectation = expectation(description: "error handler called")
        var capturedError: Error?
        let testError = NSError(domain: "TestError", code: 42)
        
        let container = makeContainer()
        let stack = CoreDataStack(
            container: container,
            errorHandler: { error in
            capturedError = error
            expectation.fulfill()
        },
            shouldAssertOnError: false,
            loadPersistentStoresHandler: failingLoadHandler(with: testError)
        )
        Self.retentionBag.append(stack)
        
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual((capturedError as NSError?)?.domain, "TestError")
        XCTAssertEqual((capturedError as NSError?)?.code, 42)
    }

    /// Если включено shouldAssertOnError, срабатывает assertion handler
    func testInitializerWhenShouldAssertTriggersAssertionHandler() {
        let expectation = expectation(description: "assertion triggered")
        CoreDataStack.assertionHandler = { message in
            if message.contains("Unresolved Core Data error") {
                expectation.fulfill()
            }
        }
        let container = makeContainer()
        let stack = CoreDataStack(
            container: container,
            errorHandler: nil,
            shouldAssertOnError: true,
            loadPersistentStoresHandler: failingLoadHandler()
        )
        Self.retentionBag.append(stack)
        wait(for: [expectation], timeout: 1.0)
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

        let container = makeContainer()
        let stack = CoreDataStack(
            container: container,
            errorHandler: nil,
            shouldAssertOnError: true,
            loadPersistentStoresHandler: failingLoadHandler()
        )
        Self.retentionBag.append(stack)

        wait(for: [expectation], timeout: 1.0)
        CoreDataStack.resetAssertionFailureAction()
    }
}

/// Вспомогательные фабрики для тестового контейнера и обработчика загрузки
private extension CoreDataStackTests {
    func makeContainer() -> NSPersistentContainer {
        let model = NSManagedObjectModel()
        return NSPersistentContainer(name: "Test", managedObjectModel: model)
    }

    func failingLoadHandler(with error: Error = NSError(domain: "TestError", code: 42)) -> (NSPersistentContainer, @escaping (NSPersistentStoreDescription, Error?) -> Void) -> Void {
        { container, completion in
            let description = container.persistentStoreDescriptions.first ?? NSPersistentStoreDescription()
            completion(description, error)
        }
    }
}

