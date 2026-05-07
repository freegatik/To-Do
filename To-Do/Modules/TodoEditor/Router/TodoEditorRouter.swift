//
//  TodoEditorRouter.swift
//  To-Do
//
//  Created by Anton Solovev on 26.07.2023.
//

import UIKit

@MainActor
protocol TodoEditorRouterProtocol: AnyObject {
    func dismiss()
}

@MainActor
final class TodoEditorRouter: TodoEditorRouterProtocol {
    weak var viewController: UIViewController?

    private let dismissPerformer: TodoEditorDismissPerformer

    init(dismissPerformer: TodoEditorDismissPerformer) {
        self.dismissPerformer = dismissPerformer
    }

    @MainActor
    static func buildModule(
        mode: TodoEditorMode,
        repository: TodoRepositoryProtocol,
        output: TodoEditorModuleOutput?
    ) -> UIViewController {
        let viewController = TodoEditorViewController()
        let interactor = TodoEditorInteractor(repository: repository, mode: mode)
        let router = TodoEditorRouter(dismissPerformer: TodoEditorUIKitDismissPerformer())
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
        dismissPerformer.dismiss(from: viewController)
    }

    static func shouldUseNavigationPop(for navigationController: UINavigationController?) -> Bool {
        guard let navigationController else { return false }
        return navigationController.viewControllers.count > 1
    }
}
