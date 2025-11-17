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

