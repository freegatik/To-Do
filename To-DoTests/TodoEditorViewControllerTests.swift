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

        guard alert.action(withTitle: "Сохранить") != nil else {
            XCTFail("Missing save action")
            return
        }
        XCTAssertTrue(sut.triggerAlertActionHandlerForTests(.save))
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

        guard alert.action(withTitle: "Выйти без сохранения") != nil else {
            XCTFail("Missing discard action")
            return
        }
        XCTAssertTrue(sut.triggerAlertActionHandlerForTests(.discard))
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

        XCTAssertTrue(sut.triggerAlertActionHandlerForTests(.discard))

        XCTAssertEqual(saveCallCount, 0)
        XCTAssertEqual(discardCallCount, 1)
    }

    func testPresentExitConfirmationSaveActionHandlerInvokesCallback() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.isUITestEnvironment = false
        var saveCallCount = 0

        sut.presentExitConfirmation(canSave: true, onSave: { saveCallCount += 1 }, onDiscard: {})
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        guard let alert = sut.presentedViewController as? UIAlertController else {
            XCTFail("Expected alert to be presented")
            return
        }

        XCTAssertNotNil(alert.action(withTitle: "Сохранить"))
        XCTAssertTrue(sut.triggerAlertActionHandlerForTests(.save))
        XCTAssertEqual(saveCallCount, 1)
    }


    func testPresentExitConfirmationCancelActionClearsHandlers() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.isUITestEnvironment = false

        sut.presentExitConfirmation(canSave: true, onSave: {}, onDiscard: {})
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        guard sut.presentedViewController is UIAlertController else {
            XCTFail("Expected alert to be presented")
            return
        }

        XCTAssertTrue(sut.triggerAlertActionHandlerForTests(.cancel))

#if DEBUG
        XCTAssertNil(sut.lastExitConfirmationHandlers.save)
        XCTAssertNil(sut.lastExitConfirmationHandlers.discard)
#endif
    }

    func testTriggerExitSaveHandlerInvokesSavedClosure() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.isUITestEnvironment = false
        var saveCallCount = 0

        sut.presentExitConfirmation(canSave: true, onSave: { saveCallCount += 1 }, onDiscard: {})
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.triggerExitSaveHandlerForTests()

        XCTAssertEqual(saveCallCount, 1)
    }

    func testTriggerExitDiscardHandlerInvokesDiscardClosure() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.isUITestEnvironment = false
        var discardCallCount = 0

        sut.presentExitConfirmation(canSave: true, onSave: {}, onDiscard: { discardCallCount += 1 })
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.triggerExitDiscardHandlerForTests()

        XCTAssertEqual(discardCallCount, 1)
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

    /// presentExitConfirmation настраивает popoverPresentationController когда он доступен
    func testPresentExitConfirmationConfiguresPopoverWhenAvailable() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.isUITestEnvironment = false

        sut.presentExitConfirmation(canSave: true, onSave: {}, onDiscard: {})
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        guard let alert = sut.presentedViewController as? UIAlertController else {
            XCTFail("Expected alert to be presented")
            return
        }

        if let popover = alert.popoverPresentationController {
            XCTAssertEqual(popover.sourceView, sut.backButtonForTests)
            XCTAssertEqual(popover.sourceRect, sut.backButtonForTests.bounds)
        }
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

    /// Уведомления клавиатуры игнорируются, если отсутствуют необходимые данные
    func testKeyboardNotificationsIgnoreWhenMissingData() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.viewWillAppear(false)

        let initialInset = sut.scrollViewForTests.contentInset.bottom

        // Отправляем уведомление без frame (должно быть проигнорировано)
        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil, userInfo: [
            UIResponder.keyboardAnimationDurationUserInfoKey: NSNumber(value: 0.0)
        ])
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(sut.scrollViewForTests.contentInset.bottom, initialInset)

        // Отправляем уведомление без duration (должно быть проигнорировано)
        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil, userInfo: [
            UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: CGRect(x: 0, y: 0, width: 320, height: 150))
        ])
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(sut.scrollViewForTests.contentInset.bottom, initialInset)

        // Отправляем уведомление hide без duration (должно быть проигнорировано)
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil, userInfo: [:])
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(sut.scrollViewForTests.contentInset.bottom, initialInset)

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

    /// textViewDidBeginEditing обновляет плейсхолдеры
    func testTextViewDidBeginEditingUpdatesPlaceholders() {
        let (sut, _) = makeSUT()
        loadView(of: sut)

        sut.titleTextViewForTests.text = ""
        sut.bodyTextViewForTests.text = ""
        sut.textViewDidBeginEditing(sut.titleTextViewForTests)
        sut.textViewDidBeginEditing(sut.bodyTextViewForTests)
        XCTAssertFalse(sut.titlePlaceholderForTests.isHidden)
        XCTAssertFalse(sut.bodyPlaceholderForTests.isHidden)

        sut.titleTextViewForTests.text = "text"
        sut.bodyTextViewForTests.text = "body"
        sut.textViewDidBeginEditing(sut.titleTextViewForTests)
        sut.textViewDidBeginEditing(sut.bodyTextViewForTests)
        XCTAssertTrue(sut.titlePlaceholderForTests.isHidden)
        XCTAssertTrue(sut.bodyPlaceholderForTests.isHidden)
    }

    /// textViewDidEndEditing обновляет плейсхолдеры
    func testTextViewDidEndEditingUpdatesPlaceholders() {
        let (sut, _) = makeSUT()
        loadView(of: sut)

        sut.titleTextViewForTests.text = ""
        sut.bodyTextViewForTests.text = ""
        sut.textViewDidEndEditing(sut.titleTextViewForTests)
        sut.textViewDidEndEditing(sut.bodyTextViewForTests)
        XCTAssertFalse(sut.titlePlaceholderForTests.isHidden)
        XCTAssertFalse(sut.bodyPlaceholderForTests.isHidden)

        sut.titleTextViewForTests.text = "text"
        sut.bodyTextViewForTests.text = "body"
        sut.textViewDidEndEditing(sut.titleTextViewForTests)
        sut.textViewDidEndEditing(sut.bodyTextViewForTests)
        XCTAssertTrue(sut.titlePlaceholderForTests.isHidden)
        XCTAssertTrue(sut.bodyPlaceholderForTests.isHidden)
    }

    /// configure с nil createdAtText скрывает dateLabel и устанавливает константу в 0
    func testConfigureWithNilCreatedAtTextHidesDateLabel() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        let viewModel = TodoEditorViewModel(title: "Title", details: "Details", isCompleted: false, createdAtText: nil)

        sut.configure(with: viewModel)

        XCTAssertTrue(sut.dateLabelForTests.isHidden)
        XCTAssertEqual(sut.bodyTopToDateConstraintForTests.constant, 0)
    }

    /// configure с непустым title не вызывает becomeFirstResponder
    func testConfigureWithNonEmptyTitleDoesNotBecomeFirstResponder() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        let viewModel = TodoEditorViewModel(title: "Title", details: "Details", isCompleted: false, createdAtText: nil)

        sut.configure(with: viewModel)

        XCTAssertFalse(sut.titleTextViewForTests.isFirstResponder)
    }

    /// keyboardWillShowNotification с отсутствующим userInfo не изменяет contentInset
    func testKeyboardWillShowNotificationWithMissingUserInfoDoesNothing() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.viewWillAppear(false)

        let initialInset = sut.scrollViewForTests.contentInset.bottom

        // Отправляем уведомление без userInfo
        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil, userInfo: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        // contentInset не должен измениться
        XCTAssertEqual(sut.scrollViewForTests.contentInset.bottom, initialInset)

        sut.viewWillDisappear(false)
    }

    /// keyboardWillShowNotification с отсутствующим frame не изменяет contentInset
    func testKeyboardWillShowNotificationWithMissingFrameDoesNothing() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.viewWillAppear(false)

        let initialInset = sut.scrollViewForTests.contentInset.bottom

        // Отправляем уведомление только с duration, без frame
        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil, userInfo: [
            UIResponder.keyboardAnimationDurationUserInfoKey: NSNumber(value: 0.0)
        ])
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        // contentInset не должен измениться
        XCTAssertEqual(sut.scrollViewForTests.contentInset.bottom, initialInset)

        sut.viewWillDisappear(false)
    }

    /// keyboardWillHideNotification с отсутствующим duration не изменяет contentInset
    func testKeyboardWillHideNotificationWithMissingDurationDoesNothing() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.viewWillAppear(false)

        // Сначала показываем клавиатуру
        let frame = CGRect(x: 0, y: 0, width: 320, height: 150)
        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil, userInfo: [
            UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: frame),
            UIResponder.keyboardAnimationDurationUserInfoKey: NSNumber(value: 0.0)
        ])
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let insetAfterShow = sut.scrollViewForTests.contentInset.bottom

        // Отправляем уведомление скрытия без duration
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil, userInfo: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        // contentInset не должен измениться (остается как после показа)
        XCTAssertEqual(sut.scrollViewForTests.contentInset.bottom, insetAfterShow)

        sut.viewWillDisappear(false)
    }

    /// triggerAlertActionHandlerForTests возвращает false когда handler отсутствует
    func testTriggerAlertActionHandlerForTestsWhenHandlerMissingReturnsFalse() {
        let (sut, _) = makeSUT()
        loadView(of: sut)

        // Не вызываем presentExitConfirmation, поэтому handlers не установлены
        let result = sut.triggerAlertActionHandlerForTests(.save)

        XCTAssertFalse(result)
    }

    /// performExitSelectionForTests когда save handler nil ничего не делает
    func testPerformExitSelectionForTestsWhenSaveHandlerIsNilDoesNothing() {
        let (sut, _) = makeSUT()
        loadView(of: sut)

        // Не вызываем presentExitConfirmation, поэтому lastExitConfirmationHandlers.save будет nil
        var saveCalled = false
        var discardCalled = false

        // Устанавливаем только discard handler через presentExitConfirmation без canSave
        sut.presentExitConfirmation(canSave: false, onSave: { saveCalled = true }, onDiscard: { discardCalled = true })
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        // Теперь save handler должен быть nil, а discard handler установлен
        // Вызываем performExitSelectionForTests(.save) - ничего не должно произойти
        sut.performExitSelectionForTests(.save)

        XCTAssertFalse(saveCalled)
        XCTAssertFalse(discardCalled)
    }

    /// performExitSelectionForTests когда discard handler nil ничего не делает
    func testPerformExitSelectionForTestsWhenDiscardHandlerIsNilDoesNothing() {
        let (sut, _) = makeSUT()
        loadView(of: sut)

        // Не вызываем presentExitConfirmation, поэтому lastExitConfirmationHandlers.discard будет nil
        var saveCalled = false
        var discardCalled = false

        // Устанавливаем только save handler через presentExitConfirmation с canSave: true
        // Но не устанавливаем discard handler явно
        sut.presentExitConfirmation(canSave: true, onSave: { saveCalled = true }, onDiscard: { discardCalled = true })
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        // Очищаем handlers, чтобы discard был nil
        sut.performExitSelectionForTests(.cancel)

        // Теперь discard handler должен быть nil
        // Вызываем performExitSelectionForTests(.discard) - ничего не должно произойти
        sut.performExitSelectionForTests(.discard)

        XCTAssertFalse(saveCalled)
        XCTAssertFalse(discardCalled)
    }

    /// presentExitConfirmation когда popoverFallbackHandler nil не крашится
    func testPresentExitConfirmationWhenPopoverFallbackHandlerIsNilDoesNotCrash() {
        let (sut, _) = makeSUT()
        loadView(of: sut)
        sut.isUITestEnvironment = false

        // Убеждаемся, что popoverFallbackHandler nil
        TodoEditorViewController.popoverFallbackHandler = nil

        // Вызываем presentExitConfirmation - не должно быть краша
        sut.presentExitConfirmation(canSave: true, onSave: {}, onDiscard: {})
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        // Тест проходит, если не произошло краша
        XCTAssertNotNil(sut.presentedViewController)
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

private extension UIAlertAction {
    func performHandler(file: StaticString = #filePath, line: UInt = #line) {
        guard let handler = value(forKey: "handler") as? (UIAlertAction) -> Void else {
            XCTFail("Missing handler for action \(title ?? "<no title>")", file: file, line: line)
            return
        }
        handler(self)
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

