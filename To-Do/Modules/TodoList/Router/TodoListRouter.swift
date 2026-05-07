//
//  TodoListRouter.swift
//  To-Do
//
//  Created by Anton Solovev on 18.07.2023.
//

import UIKit

@MainActor
protocol TodoListRouterProtocol: AnyObject {
    func presentEditor(mode: TodoEditorMode, output: TodoEditorModuleOutput)
}

@MainActor
final class TodoListRouter: TodoListRouterProtocol {
    weak var viewController: UIViewController?

    private let repository: TodoRepositoryProtocol

    init(repository: TodoRepositoryProtocol) {
        self.repository = repository
    }

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

