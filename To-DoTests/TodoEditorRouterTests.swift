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
final class TodoEditorRouterTests: XCTestCase {
    /// Фабрика модуля возвращает настроенный контроллер и презентер
    func testBuildModuleConfiguresDependencies() {
        let repository = MockRepository()
        let output = MockOutput()

        let viewController = TodoEditorRouter.buildModule(mode: .create, repository: repository, output: output)

        XCTAssertTrue(viewController is TodoEditorViewController)
        let editorVC = viewController as! TodoEditorViewController
        XCTAssertNotNil(editorVC.presenter)
    }

    /// Если редактор внутри навигации, router вызывает pop
    func testDismissPopsWhenInsideNavigationController() {
        let router = TodoEditorRouter()
        let root = UIViewController()
        let editor = UIViewController()
        let navigation = NavigationControllerSpy()
        navigation.setViewControllers([root, editor], animated: false)
        router.viewController = editor

        router.dismiss()

        XCTAssertEqual(navigation.popCallCount, 1)
    }

    /// При отсутствии навигации router выполняет модальный dismiss
    func testDismissDismissesModallyWhenNoNavigationStack() {
        let router = TodoEditorRouter()
        let viewController = DismissSpyViewController()
        router.viewController = viewController

        router.dismiss()

        XCTAssertEqual(viewController.dismissCallCount, 1)
    }
}

/// Навигационный контроллер с подсчётом вызовов pop
private final class NavigationControllerSpy: UINavigationController {
    var popCallCount = 0

    override func popViewController(animated: Bool) -> UIViewController? {
        popCallCount += 1
        return super.popViewController(animated: animated)
    }
}

/// Заглушка UIViewController, считающая количество закрытий
private final class DismissSpyViewController: UIViewController {
    var dismissCallCount = 0

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissCallCount += 1
        completion?()
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

