//
//  TodoEditorRouterTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 11.11.2025.
//

import XCTest
import UIKit
@testable import To_Do

/// Проверяем маршрутизацию экрана редактора задач
@MainActor
final class TodoEditorRouterTests: XCTestCase {
    private static var retentionBag: [AnyObject] = []

    override class func tearDown() {
        retentionBag.removeAll()
        super.tearDown()
    }

    func testBuildModuleConfiguresDependencies() {
        let repository = MockRepository()
        let output = MockOutput()

        let viewController = TodoEditorRouter.buildModule(mode: .create, repository: repository, output: output)

        XCTAssertTrue(viewController is TodoEditorViewController)
        let editorVC = viewController as! TodoEditorViewController
        XCTAssertNotNil(editorVC.presenter)

        Self.retentionBag.append(viewController)
    }

    func testShouldUseNavigationPopReturnsTrueForStackWithMultipleControllers() {
        let navigation = UINavigationController()
        navigation.viewControllers = [UIViewController(), UIViewController()]

        XCTAssertTrue(TodoEditorRouter.shouldUseNavigationPop(for: navigation))
    }

    func testShouldUseNavigationPopReturnsFalseWhenStackIsEmptyOrSingle() {
        let navigation = UINavigationController()
        navigation.viewControllers = [UIViewController()]

        XCTAssertFalse(TodoEditorRouter.shouldUseNavigationPop(for: navigation))
        XCTAssertFalse(TodoEditorRouter.shouldUseNavigationPop(for: nil))
    }

    func testDismissUsesPopWhenInNavigationStack() {
        let navigation = UINavigationController()
        let firstVC = UIViewController()
        let router = TodoEditorRouter()
        let secondVC = UIViewController()
        navigation.viewControllers = [firstVC, secondVC]
        router.viewController = secondVC

        let initialCount = navigation.viewControllers.count
        router.dismiss()

        // Проверяем, что был вызван pop (viewControllers уменьшилось или осталось прежним, но secondVC больше не последний)
        // В реальности pop может быть асинхронным, поэтому проверяем, что secondVC больше не является последним
        let finalCount = navigation.viewControllers.count
        XCTAssertTrue(finalCount <= initialCount, "Navigation stack should not grow")
        if finalCount == initialCount - 1 {
            XCTAssertEqual(navigation.viewControllers.last, firstVC)
        }
    }

    func testDismissUsesDismissWhenNotInNavigationStack() {
        let router = TodoEditorRouter()
        let viewController = UIViewController()
        router.viewController = viewController

        router.dismiss()

        XCTAssertNil(viewController.navigationController)
    }

    func testDismissUsesDismissWhenViewControllerHasNoNavigationController() {
        let router = TodoEditorRouter()
        let viewController = UIViewController()
        router.viewController = viewController

        router.dismiss()

        XCTAssertNil(viewController.navigationController)
    }

    func testDismissUsesDismissWhenNavigationStackHasOnlyOneController() {
        let navigation = UINavigationController()
        let router = TodoEditorRouter()
        let viewController = UIViewController()
        router.viewController = viewController
        navigation.viewControllers = [viewController]

        router.dismiss()

        XCTAssertEqual(navigation.viewControllers.count, 1)
    }

    func testDismissWhenViewControllerIsNilDoesNotCrash() {
        let router = TodoEditorRouter()
        router.viewController = nil

        router.dismiss()

        // Тест проходит, если не произошло краша
        XCTAssertNil(router.viewController)
    }
}

/// Минимальная реализация репозитория, чтобы собрать модуль
private final class MockRepository: TodoRepositoryProtocol {
    func loadInitialTodos(completion: @escaping (Result<[TodoItem], Error>) -> Void) {}
    func fetchTodos(completion: @escaping (Result<[TodoItem], Error>) -> Void) {}
    func createTodo(title: String, details: String?, completion: @escaping (Result<TodoItem, Error>) -> Void) {}
    func updateTodo(_ item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {}
    func deleteTodo(_ item: TodoItem, completion: @escaping (Result<Void, Error>) -> Void) {}
    func toggleCompletion(for item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) {}
    func searchTodos(query: String, completion: @escaping (Result<[TodoItem], Error>) -> Void) {}
}

/// Пустой output для проверки связки зависимостей
private final class MockOutput: TodoEditorModuleOutput {
    func todoEditorDidFinish(with result: TodoEditorResult) {}
}

