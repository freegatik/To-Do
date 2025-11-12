//
//  TodoListRouter.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import UIKit

/// Роутер делает переходы из списка
protocol TodoListRouterProtocol: AnyObject {
    func presentEditor(mode: TodoEditorMode, output: TodoEditorModuleOutput)
}

/// Реализация роутера для списка задач
final class TodoListRouter: TodoListRouterProtocol {
    weak var viewController: UIViewController?

    private let repository: TodoRepositoryProtocol

    /// Передаём репозиторий, чтобы делиться им с редактором
    init(repository: TodoRepositoryProtocol) {
        self.repository = repository
    }

    /// Собираем модуль и связываем компоненты
    static func buildModule(repository: TodoRepositoryProtocol) -> UIViewController {
        let viewController = TodoListViewController()
        let interactor = TodoListInteractor(repository: repository)
        let router = TodoListRouter(repository: repository)
        let presenter = TodoListPresenter(view: viewController, interactor: interactor, router: router)

        viewController.presenter = presenter
        interactor.output = presenter
        router.viewController = viewController

        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    /// Показываем редактор задачи внутри навигации
    func presentEditor(mode: TodoEditorMode, output: TodoEditorModuleOutput) {
        let editor = TodoEditorRouter.buildModule(mode: mode, repository: repository, output: output)
        if let navigationController = viewController?.navigationController {
            navigationController.pushViewController(editor, animated: true)
        } else {
            let navigation = UINavigationController(rootViewController: editor)
            navigation.modalPresentationStyle = .fullScreen
            viewController?.present(navigation, animated: true, completion: nil)
        }
    }
}

