//
//  TodoEditorRouter.swift
//  To-Do
//
//  Created by Anton Solovev on 07.11.2025.
//

import UIKit

/// Роутер редактора закрывает экран
protocol TodoEditorRouterProtocol: AnyObject {
    func dismiss()
}

/// Реализация роутера редактора
final class TodoEditorRouter: TodoEditorRouterProtocol {
    weak var viewController: UIViewController?

    /// Собираем модуль редактора под конкретный режим
    static func buildModule(
        mode: TodoEditorMode,
        repository: TodoRepositoryProtocol,
        output: TodoEditorModuleOutput?
    ) -> UIViewController {
        let viewController = TodoEditorViewController()
        let interactor = TodoEditorInteractor(repository: repository, mode: mode)
        let router = TodoEditorRouter()
        let presenter = TodoEditorPresenter(
            view: viewController,
            interactor: interactor,
            router: router,
            output: output,
            mode: mode
        )

        viewController.presenter = presenter
        interactor.output = presenter
        router.viewController = viewController

        return viewController
    }

    func dismiss() {
        if let navigationController = viewController?.navigationController, navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
        } else {
            viewController?.dismiss(animated: true, completion: nil)
        }
    }
}

