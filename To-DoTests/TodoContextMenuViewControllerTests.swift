//
//  TodoContextMenuViewControllerTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 11.11.2025.
//

import XCTest
@testable import To_Do

/// Проверяем, как контекстное меню задач реагирует на пользовательские действия
@MainActor
final class TodoContextMenuViewControllerTests: XCTestCase {
    private var window: UIWindow!

    override func setUp() async throws {
        try await super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
    }

    override func tearDown() async throws {
        window.isHidden = true
        window = nil
        try await super.tearDown()
    }

    /// При загрузке контроллера создаются три кнопки с нужными идентификаторами
    func testViewDidLoadCreatesThreeConfiguredButtons() throws {
        let sut = makeSUT(details: "Описание", anchorRect: CGRect(x: 40, y: 80, width: 200, height: 60))
        sut.loadViewIfNeeded()

        let actionsStack: UIStackView = try sut.element(named: "actionsStack")
        XCTAssertEqual(actionsStack.arrangedSubviews.count, 3)

        let identifiers = actionsStack.arrangedSubviews.compactMap { $0.accessibilityIdentifier }
        XCTAssertEqual(identifiers, ["context.edit", "context.share", "context.delete"])
    }

    /// Отсутствие описания скрывает соответствующий label и текст
    func testApplyViewModelHidesDetailsWhenMissing() throws {
        let sut = makeSUT(details: nil, anchorRect: CGRect(x: 40, y: 80, width: 200, height: 60))
        sut.loadViewIfNeeded()

        let detailsLabel: UILabel = try sut.element(named: "detailsLabel")
        XCTAssertTrue(detailsLabel.isHidden)
        XCTAssertNil(detailsLabel.attributedText)
    }

    /// Если описание заполнено, лейбл отображает атрибутированный текст
    func testApplyViewModelShowsDetailsWhenPresent() throws {
        let sut = makeSUT(details: "Комментарий", anchorRect: CGRect(x: 40, y: 80, width: 200, height: 60))
        sut.loadViewIfNeeded()

        let detailsLabel: UILabel = try sut.element(named: "detailsLabel")
        XCTAssertFalse(detailsLabel.isHidden)
        XCTAssertNotNil(detailsLabel.attributedText)
    }

    /// Завершённая задача убирает тень и добавляет зачёркивание
    func testCompletedTaskRemovesShadowAndAddsStrikeThrough() throws {
        let sut = makeSUT(details: "Описание", isCompleted: true, anchorRect: CGRect(x: 40, y: 80, width: 200, height: 60))
        sut.loadViewIfNeeded()

        let taskCard: UIView = try sut.element(named: "taskCard")
        XCTAssertEqual(taskCard.layer.shadowOpacity, 0)

        let titleLabel: UILabel = try sut.element(named: "titleLabel")
        let attributed = try XCTUnwrap(titleLabel.attributedText)
        let strike = attributed.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(strike, NSUnderlineStyle.single.rawValue)
    }

    /// updatePreferredPosition ограничивает позицию меню в пределах экрана
    func testUpdatePreferredPositionClampsToVisibleArea() throws {
        let frame = CGRect(x: 0, y: 0, width: 320, height: 620)
        let anchor = CGRect(x: 400, y: 700, width: 160, height: 60)
        let sut = makeSUT(details: "Описание", anchorRect: anchor)
        sut.view.frame = frame
        sut.loadViewIfNeeded()

        // Force layout to compute target size
        sut.view.layoutIfNeeded()
        sut.viewDidLayoutSubviews()

        let containerStack: UIStackView = try sut.element(named: "containerStack")
        let centerXConstraint: NSLayoutConstraint = try sut.element(named: "centerXConstraint")
        let topConstraint: NSLayoutConstraint = try sut.element(named: "topConstraint")

        let safe = sut.view.safeAreaInsets
        let maxWidth = sut.view.bounds.width - (safe.left + safe.right) - 40
        let fittingWidth = maxWidth > 0 ? maxWidth : sut.view.bounds.width
        let targetSize = containerStack.systemLayoutSizeFitting(
            CGSize(width: fittingWidth, height: UIView.layoutFittingCompressedSize.height)
        )
        let halfWidth = min(targetSize.width, fittingWidth) / 2
        let minCenterX = safe.left + 20 + halfWidth
        let maxCenterX = sut.view.bounds.width - safe.right - 20 - halfWidth
        XCTAssertGreaterThanOrEqual(centerXConstraint.constant, minCenterX - 0.5)
        XCTAssertLessThanOrEqual(centerXConstraint.constant, maxCenterX + 0.5)

        let minTop = safe.top + 16.0
        let maxTop = sut.view.bounds.height - safe.bottom - 16.0 - targetSize.height
        XCTAssertGreaterThanOrEqual(topConstraint.constant, minTop - 0.5)
        XCTAssertLessThanOrEqual(topConstraint.constant, maxTop + 0.5)
    }

    /// performAndDismiss вызывает действие, сбрасывает флаг и сообщает о закрытии
    func testPerformAndDismissInvokesCallbacksAndResetsFlag() throws {
        let sut = makeSUT(details: "Описание", anchorRect: CGRect(x: 40, y: 80, width: 220, height: 60))
        var editCount = 0
        var shareCount = 0
        var deleteCount = 0
        var dismissCount = 0
        let expectation = expectation(description: "Delete action completion")
        expectation.expectedFulfillmentCount = 1

        sut.onEdit = { editCount += 1 }
        sut.onShare = { shareCount += 1 }
        sut.onDelete = {
            deleteCount += 1
        }
        sut.onDismiss = {
            dismissCount += 1
            expectation.fulfill()
        }

        try present(sut)
        sut.loadViewIfNeeded()

        let actionsStack: UIStackView = try sut.element(named: "actionsStack")
        guard let deleteButton = actionsStack.arrangedSubviews.last as? UIButton else {
            XCTFail("Delete button not found")
            return
        }

        deleteButton.sendActions(for: .touchUpInside)
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(deleteCount, 1)
        XCTAssertEqual(dismissCount, 1)
        XCTAssertEqual(editCount, 0)
        XCTAssertEqual(shareCount, 0)

        let isPerformingAction: Bool = try sut.element(named: "isPerformingAction")
        XCTAssertFalse(isPerformingAction)
    }

    func testViewDidDisappearWithoutActionCallsOnDismiss() throws {
        let sut = makeSUT(details: nil, anchorRect: CGRect(x: 40, y: 80, width: 200, height: 60))
        var dismissCount = 0
        sut.onDismiss = { dismissCount += 1 }

        sut.loadViewIfNeeded()
        sut.viewDidDisappear(false)

        XCTAssertEqual(dismissCount, 1)
    }

    func testHandleBackgroundTapDismissesController() throws {
        let sut = makeSUT(details: "Описание", anchorRect: CGRect(x: 40, y: 80, width: 200, height: 60))
        let expectation = expectation(description: "Dismiss on background tap")
        sut.onDismiss = {
            expectation.fulfill()
        }

        try present(sut)
        sut.loadViewIfNeeded()

        sut.perform(NSSelectorFromString("handleBackgroundTap"))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleEditInvokesCallback() throws {
        let sut = makeSUT(details: "Описание", anchorRect: CGRect(x: 40, y: 80, width: 200, height: 60))
        var editCount = 0
        let expectation = expectation(description: "Edit action dismiss")

        sut.onEdit = { editCount += 1 }
        sut.onDismiss = { expectation.fulfill() }

        try present(sut)
        sut.loadViewIfNeeded()

        sut.perform(NSSelectorFromString("handleEdit"))
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(editCount, 1)
    }

    func testHandleShareInvokesCallback() throws {
        let sut = makeSUT(details: "Описание", anchorRect: CGRect(x: 40, y: 80, width: 200, height: 60))
        var shareCount = 0
        let expectation = expectation(description: "Share action dismiss")

        sut.onShare = { shareCount += 1 }
        sut.onDismiss = { expectation.fulfill() }

        try present(sut)
        sut.loadViewIfNeeded()

        sut.perform(NSSelectorFromString("handleShare"))
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(shareCount, 1)
    }

    // Вспомогательные методы для ожидания и доступа к элементам

    /// Создаёт экземпляр меню с указанными параметрами
    private func makeSUT(
        details: String?,
        isCompleted: Bool = false,
        anchorRect: CGRect
    ) -> TodoContextMenuViewController {
        let viewModel = TodoContextMenuViewModel(
            title: "Задача",
            details: details,
            date: "11 ноября",
            isCompleted: isCompleted
        )
        return TodoContextMenuViewController(viewModel: viewModel, anchorRect: anchorRect)
    }

    /// Презентует контроллер поверх корневого окна тестов
    private func present(_ sut: UIViewController) throws {
        guard let host = window.rootViewController else {
            XCTFail("Root view controller is missing")
            return
        }
        host.present(sut, animated: false)
    }
}

// Reflection-хелперы для доступа к приватным свойствам

private extension TodoContextMenuViewController {
    /// Возвращает приватное свойство контроллера по имени
    func element<T>(named name: String) throws -> T {
        var mirror: Mirror? = Mirror(reflecting: self)
        while let current = mirror {
            if let value = current.children.first(where: { $0.label == name })?.value as? T {
                return value
            }
            mirror = current.superclassMirror
        }
        throw NSError(domain: "TodoContextMenuViewControllerTests", code: 0, userInfo: [NSLocalizedDescriptionKey: "Property \(name) not found"])
    }
}


