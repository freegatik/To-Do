//
//  TodoEditorViewControllerTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 11.11.2025.
//

import XCTest
import UIKit
@testable import To_Do

/// Проверяем поведение контроллера редактора задач и его связей с UI
@MainActor
final class TodoEditorViewControllerTests: XCTestCase {
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        window = nil
        super.tearDown()
    }

    /// После загрузки viewcontroller запрашивает данные у презентера
    func testViewDidLoadAsksPresenterForInitialData() {
        let (sut, presenter) = makeSUT()

        loadView(of: sut)

        XCTAssertEqual(presenter.viewDidLoadCallCount, 1)
    }

    /// Настройка завершённой задачи показывает бейдж статуса и скрывает дату
    func testConfigureWithCompletedTodoShowsStatusBadge() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        let viewModel = TodoEditorViewModel(title: "Title", details: "Details", isCompleted: true, createdAtText: "Сегодня")

        sut.configure(with: viewModel)

        XCTAssertEqual(sut.titleTextViewForTests.text, "Title")
        XCTAssertEqual(sut.bodyTextViewForTests.text, "Details")
        XCTAssertEqual(sut.dateLabelForTests.text, "Сегодня")
        XCTAssertFalse(sut.statusBadgeForTests.isHidden)
        XCTAssertTrue(sut.bodyTopToStatusConstraintForTests.isActive)
        XCTAssertFalse(sut.bodyTopToDateConstraintForTests.isActive)
    }

    /// Незавершённая задача скрывает бейдж и делает поля активными
    func testConfigureWithActiveTodoHidesStatusBadge() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        let viewModel = TodoEditorViewModel(title: "", details: "", isCompleted: false, createdAtText: nil)

        sut.configure(with: viewModel)

        XCTAssertTrue(sut.statusBadgeForTests.isHidden)
        XCTAssertFalse(sut.bodyTopToStatusConstraintForTests.isActive)
        XCTAssertTrue(sut.bodyTopToDateConstraintForTests.isActive)
        XCTAssertTrue(sut.titleTextViewForTests.isFirstResponder)
    }

    /// showLoading управляет кнопкой Back и индикатором активности
    func testShowLoadingControlsIndicatorAndBackButton() {
        let (sut, _) = makeSUT()
        loadView(of: sut)

        sut.showLoading(true)
        XCTAssertFalse(sut.backButtonForTests.isEnabled)
        XCTAssertTrue(sut.activityIndicatorForTests.isAnimating)

        sut.showLoading(false)
        XCTAssertTrue(sut.backButtonForTests.isEnabled)
        XCTAssertFalse(sut.activityIndicatorForTests.isAnimating)
    }

    /// showError выводит UIAlertController с переданным сообщением
    func testShowErrorPresentsAlert() {
        let (sut, _) = makeSUT()
        loadView(of: sut)

        sut.showError(message: "Ошибка сохранения")
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        let presented = sut.presentedViewController as? UIAlertController
        XCTAssertNotNil(presented)
        XCTAssertEqual(presented?.message, "Ошибка сохранения")
    }

    /// В UI-тестовой среде при canSave=true сразу вызывается обработчик сохранения
    func testPresentExitConfirmationInUITestModeCallsSaveWhenAllowed() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.isUITestEnvironment = true
        let saveExpectation = expectation(description: "save called")

        sut.presentExitConfirmation(canSave: true, onSave: { saveExpectation.fulfill() }, onDiscard: { XCTFail("Discard should not be called") })

        wait(for: [saveExpectation], timeout: 0.1)
    }

    /// При canSave=false в UI-тестовой среде вызывается discard и диалог не показывается
    func testPresentExitConfirmationInUITestModeCallsDiscardWhenCannotSave() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.isUITestEnvironment = true
        let discardExpectation = expectation(description: "discard called")

        sut.presentExitConfirmation(canSave: false, onSave: { XCTFail("Save should not be called") }, onDiscard: { discardExpectation.fulfill() })

        wait(for: [discardExpectation], timeout: 0.1)
    }

    /// В обычном режиме показывается action sheet с кнопками и обработчиками
    func testPresentExitConfirmationShowsActionSheetWithHandlers() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.isUITestEnvironment = false
        var saveCallCount = 0
        var discardCallCount = 0

        sut.presentExitConfirmation(canSave: true, onSave: { saveCallCount += 1 }, onDiscard: { discardCallCount += 1 })
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        guard let alert = sut.presentedViewController as? UIAlertController else {
            XCTFail("Expected alert to be presented")
            return
        }
        XCTAssertEqual(alert.preferredStyle, .actionSheet)
        XCTAssertTrue(alert.actions.contains(where: { $0.title == "Сохранить" }))
        XCTAssertTrue(alert.actions.contains(where: { $0.title == "Не сохранять" }))
        XCTAssertEqual(saveCallCount, 0)
        XCTAssertEqual(discardCallCount, 0)

        guard let saveAction = alert.action(withTitle: "Сохранить") else {
            XCTFail("Missing save action")
            return
        }
        XCTAssertNotNil(saveAction.value(forKey: "handler"))
    }

    /// Если сохранять нечего, отображается только destructive действие
    func testPresentExitConfirmationWithoutSavePresentsDiscardOnly() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.isUITestEnvironment = false
        var saveCallCount = 0
        var discardCallCount = 0

        sut.presentExitConfirmation(
            canSave: false,
            onSave: { saveCallCount += 1 },
            onDiscard: { discardCallCount += 1 }
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        guard let alert = sut.presentedViewController as? UIAlertController else {
            XCTFail("Expected alert to be presented")
            return
        }
        XCTAssertFalse(alert.actions.contains(where: { $0.title == "Сохранить" }))
        XCTAssertTrue(alert.actions.contains(where: { $0.title == "Выйти без сохранения" }))
        XCTAssertEqual(saveCallCount, 0)
        XCTAssertEqual(discardCallCount, 0)

        guard let discardAction = alert.action(withTitle: "Выйти без сохранения") else {
            XCTFail("Missing discard action")
            return
        }
        XCTAssertNotNil(discardAction.value(forKey: "handler"))
    }

    /// Выбор действия сохранения вызывает переданный обработчик
    func testPresentExitConfirmationSaveActionInvokesCallback() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.isUITestEnvironment = false
        var saveCallCount = 0
        var discardCallCount = 0

        sut.presentExitConfirmation(canSave: true, onSave: { saveCallCount += 1 }, onDiscard: { discardCallCount += 1 })
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        guard let alert = sut.presentedViewController as? UIAlertController else {
            XCTFail("Expected alert to be presented")
            return
        }

        XCTAssertNotNil(alert.action(withTitle: "Сохранить"))
        sut.performExitSelectionForTests(.save)

        XCTAssertEqual(saveCallCount, 1)
        XCTAssertEqual(discardCallCount, 0)
    }

    /// Действие discard вызывает нужный callback
    /// После выбора discard вызывается соответствующий обработчик
    func testPresentExitConfirmationDiscardActionInvokesCallback() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.isUITestEnvironment = false
        var saveCallCount = 0
        var discardCallCount = 0

        sut.presentExitConfirmation(canSave: false, onSave: { saveCallCount += 1 }, onDiscard: { discardCallCount += 1 })
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        guard let alert = sut.presentedViewController as? UIAlertController else {
            XCTFail("Expected alert to be presented")
            return
        }

        XCTAssertNotNil(alert.action(withTitle: "Выйти без сохранения"))
        sut.performExitSelectionForTests(.discard)

        XCTAssertEqual(saveCallCount, 0)
        XCTAssertEqual(discardCallCount, 1)
    }

    func testPresentExitConfirmationCancelActionClearsHandlers() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.isUITestEnvironment = false

        sut.presentExitConfirmation(canSave: true, onSave: {}, onDiscard: {})
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        guard let alert = sut.presentedViewController as? UIAlertController else {
            XCTFail("Expected alert to be presented")
            return
        }

        guard let cancelAction = alert.action(withTitle: "Отмена") else {
            XCTFail("Missing cancel action")
            return
        }

        sut.performExitSelectionForTests(.cancel)

#if DEBUG
        XCTAssertNil(sut.lastExitConfirmationHandlers.save)
        XCTAssertNil(sut.lastExitConfirmationHandlers.discard)
#endif
    }

    func testPresentExitConfirmationFallbackPopoverHandlerReceivesAlert() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.isUITestEnvironment = false
        let expectation = expectation(description: "fallback called")

        TodoEditorViewController.popoverFallbackHandler = { alert, button in
            XCTAssertEqual(button, sut.backButtonForTests)
            XCTAssertEqual(alert.preferredStyle, .actionSheet)
            expectation.fulfill()
        }

        sut.presentExitConfirmation(canSave: true, onSave: {}, onDiscard: {})
        wait(for: [expectation], timeout: 0.1)
        TodoEditorViewController.popoverFallbackHandler = nil
    }

    /// Уведомления клавиатуры корректируют инсет scrollView
    func testKeyboardNotificationsAdjustScrollInsets() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.viewWillAppear(false)

        let frame = CGRect(x: 0, y: 0, width: 320, height: 150)
        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil, userInfo: [
            UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: frame),
            UIResponder.keyboardAnimationDurationUserInfoKey: NSNumber(value: 0.0)
        ])
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertGreaterThan(sut.scrollViewForTests.contentInset.bottom, 0)

        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil, userInfo: [
            UIResponder.keyboardAnimationDurationUserInfoKey: NSNumber(value: 0.0)
        ])
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(sut.scrollViewForTests.contentInset.bottom, 0)

        sut.viewWillDisappear(false)
    }

    /// Изменение текста пересчитывает высоту текстовых полей
    func testTextViewDidChangeUpdatesHeightConstraints() {
        let (sut, _) = makeSUT()
        loadView(of: sut)

        let originalTitleHeight = sut.titleHeightConstraintForTests.constant
        sut.titleTextViewForTests.text = String(repeating: "Line\n", count: 5)
        sut.textViewDidChange(sut.titleTextViewForTests)

        XCTAssertGreaterThan(sut.titleHeightConstraintForTests.constant, originalTitleHeight)

        let originalBodyHeight = sut.bodyHeightConstraintForTests.constant
        sut.bodyTextViewForTests.text = String(repeating: "Body text.\n", count: 10)
        sut.textViewDidChange(sut.bodyTextViewForTests)
        XCTAssertGreaterThan(sut.bodyHeightConstraintForTests.constant, originalBodyHeight)
    }

    /// Тап по кнопке «Назад» передаёт введённый текст презентеру
    func testBackButtonTappedForwardsSanitizedTextToPresenter() {
        let (sut, presenter) = makeSUT()
        loadView(of: sut)
        sut.titleTextViewForTests.text = "  Title  "
        sut.bodyTextViewForTests.text = "  Details "

        sut.backButtonForTests.sendActions(for: .touchUpInside)

        XCTAssertEqual(presenter.lastBackAction?.title, "  Title  ")
        XCTAssertEqual(presenter.lastBackAction?.details, "  Details ")
        XCTAssertEqual(presenter.lastBackAction?.isCompleted, false)
    }

    /// textViewDidChange скрывает и показывает плейсхолдеры в зависимости от текста
    func testTextViewDidChangeUpdatesPlaceholders() {
        let (sut, _) = makeSUT()
        loadView(of: sut)

        sut.titleTextViewForTests.text = ""
        sut.bodyTextViewForTests.text = ""
        sut.textViewDidChange(sut.titleTextViewForTests)
        XCTAssertFalse(sut.titlePlaceholderForTests.isHidden)
        XCTAssertFalse(sut.bodyPlaceholderForTests.isHidden)

        sut.titleTextViewForTests.text = "text"
        sut.bodyTextViewForTests.text = "body"
        sut.textViewDidChange(sut.titleTextViewForTests)
        XCTAssertTrue(sut.titlePlaceholderForTests.isHidden)
        sut.textViewDidChange(sut.bodyTextViewForTests)
        XCTAssertTrue(sut.bodyPlaceholderForTests.isHidden)
    }

    /// Плейсхолдеры корректно реагируют на nil и непустые значения
    func testUpdatePlaceholdersHandlesNilAndNonEmptyText() {
        let (sut, _) = makeSUT()
        loadView(of: sut)

        sut.titleTextViewForTests.text = nil
        sut.bodyTextViewForTests.text = " Body "
        sut.textViewDidChange(sut.titleTextViewForTests)

        XCTAssertFalse(sut.titlePlaceholderForTests.isHidden)
        XCTAssertTrue(sut.bodyPlaceholderForTests.isHidden)
    }

    /// Создаём контроллер и заглушку презентера для теста
    private func makeSUT() -> (TodoEditorViewController, MockPresenter) {
        let sut = TodoEditorViewController()
        let presenter = MockPresenter()
        sut.presenter = presenter
        return (sut, presenter)
    }

    /// Принудительно загружаем view и привязываем его к окну
    private func loadView(of sut: TodoEditorViewController) {
        window.rootViewController = sut
        sut.loadViewIfNeeded()
    }
}

// Тестовые заглушки и утилиты

/// Упрощает поиск действий в UIAlertController
private extension UIAlertController {
    func action(withTitle title: String) -> UIAlertAction? {
        actions.first(where: { $0.title == title })
    }
}

/// Презентер-заглушка, фиксирующий обращения вью
@MainActor
private final class MockPresenter: TodoEditorPresenterProtocol {
    var viewDidLoadCallCount = 0
    var lastBackAction: (title: String, details: String?, isCompleted: Bool)?

    func viewDidLoad() {
        viewDidLoadCallCount += 1
    }

    func handleBackAction(title: String, details: String?, isCompleted: Bool) {
        lastBackAction = (title, details, isCompleted)
    }
}

