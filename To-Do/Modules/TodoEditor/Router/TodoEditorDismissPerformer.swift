//
//  TodoEditorDismissPerformer.swift
//  To-Do
//
//  Created by Anton Solovev on 26.07.2023.
//

import UIKit

@MainActor
protocol TodoEditorDismissPerformer: AnyObject {
    func dismiss(from viewController: UIViewController?)
}

@MainActor
final class TodoEditorUIKitDismissPerformer: TodoEditorDismissPerformer {
    func dismiss(from viewController: UIViewController?) {
        guard let viewController else { return }
        if TodoEditorRouter.shouldUseNavigationPop(for: viewController.navigationController) {
            viewController.navigationController?.popViewController(animated: false)
        } else {
            viewController.dismiss(animated: false, completion: nil)
        }
    }
}
