//
//  TodoListRouterTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 11.11.2025.
//

import XCTest
@testable import To_Do

/// Проверяем, как роутер списка задач открывает редактор
final class TodoListRouterTests: XCTestCase {
    private var router: TodoListRouter!
    private var repository: StubTodoRepository!
    private var output: TodoEditorModuleOutputSpy!

    override func setUp() {
        super.setUp()
        repository = StubTodoRepository()
        router = TodoListRouter(repository: repository)
        output = TodoEditorModuleOutputSpy()
    }

    override func tearDown() {
        router = nil
        repository = nil
        output = nil
        super.tearDown()
    }

    /// При наличии навигации редактор должен пушиться в стек
    func testPresentEditorPushesWhenNavigationControllerExists() {
        let navigation = SpyNavigationController(rootViewController: UIViewController())
        router.viewController = navigation.viewControllers.first

        router.presentEditor(mode: .create, output: output)

        guard let pushed = navigation.lastPushedViewController else {
            return XCTFail("Router must push editor controller when navigation stack is available")
        }
        XCTAssertTrue(pushed is TodoEditorViewController)
        XCTAssertNil(navigation.viewControllers.first?.presentedViewController, "Navigation-based presentation must not fallback to modal")
    }

    /// Без навигации роутер показывает редактор модально в обёртке UINavigationController
    func testPresentEditorPresentsModallyWhenNoNavigationController() {
        let presenter = SpyPresentingViewController()
        router.viewController = presenter

        let todo = TodoItem(id: 42, title: "Demo", details: nil, createdAt: Date(), isCompleted: false)
        router.presentEditor(mode: .edit(todo), output: output)

        guard let presentedNav = presenter.lastPresentedNavigation else {
            return XCTFail("Expected router to present navigation controller modally")
        }
        XCTAssertEqual(presentedNav.modalPresentationStyle, .fullScreen)
        XCTAssertTrue(presentedNav.viewControllers.first is TodoEditorViewController, "Editor should be embedded into presented navigation controller")
    }
}

// Тестовые заглушки и вспомогательные классы

/// Минимальная реализация репозитория для тестов роутера
private final class StubTodoRepository: TodoRepositoryProtocol {
    func loadInitialTodos(completion: @escaping (Result<[TodoItem], Error>) -> Void) { }
    func fetchTodos(completion: @escaping (Result<[TodoItem], Error>) -> Void) { }
    func createTodo(title: String, details: String?, completion: @escaping (Result<TodoItem, Error>) -> Void) { }
    func updateTodo(_ item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) { }
    func toggleCompletion(for item: TodoItem, completion: @escaping (Result<TodoItem, Error>) -> Void) { }
    func deleteTodo(_ item: TodoItem, completion: @escaping (Result<Void, Error>) -> Void) { }
    func searchTodos(query: String, completion: @escaping (Result<[TodoItem], Error>) -> Void) { }
}

/// Навигационный контроллер, запоминающий последний pushed контроллер
private final class SpyNavigationController: UINavigationController {
    private(set) var lastPushedViewController: UIViewController?

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        lastPushedViewController = viewController
        super.pushViewController(viewController, animated: animated)
    }
}

/// UIViewController, фиксирующий модальные презентации
private final class SpyPresentingViewController: UIViewController {
    private(set) var lastPresentedNavigation: UINavigationController?

    override func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        if let navigationController = viewControllerToPresent as? UINavigationController {
            lastPresentedNavigation = navigationController
        }
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }
}

/// Пустой spy, удовлетворяющий протокол модульного output
private final class TodoEditorModuleOutputSpy: TodoEditorModuleOutput {
    func todoEditorDidFinish(with result: TodoEditorResult) { }
}

