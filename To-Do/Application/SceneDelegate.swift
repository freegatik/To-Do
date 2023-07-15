//
//  SceneDelegate.swift
//  To-Do
//
//  Created by Anton Solovev on 04.07.2023.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private lazy var coreDataStack: CoreDataStackProtocol = CoreDataStack.shared
    private lazy var apiClient: TodoAPIClientProtocol = TodoAPIClient()
    private lazy var repository: TodoRepositoryProtocol = TodoRepository(
        coreDataStack: coreDataStack,
        apiClient: apiClient
    )

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = TodoListRouter.buildModule(repository: repository)
        window.makeKeyAndVisible()
        self.window = window
    }
}

