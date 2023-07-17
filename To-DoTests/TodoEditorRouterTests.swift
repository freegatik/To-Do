//
//  TodoEditorRouterTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 31.07.2023.
//

import XCTest
import UIKit
@testable import To_Do

final class TodoEditorRouterTests: XCTestCase {

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
