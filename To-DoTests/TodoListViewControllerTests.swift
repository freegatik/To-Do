//
//  TodoListViewControllerTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 11.11.2025.
//

import XCTest
import ObjectiveC
import AVFoundation
import Speech
@testable import To_Do

/// Проверяем пользовательские сценарии экрана списка задач и интеграцию с презентером
@MainActor
final class TodoListViewControllerTests: XCTestCase {
    private var sut: TodoListViewController!
    private var presenter: MockPresenter!
    private var window: UIWindow!
    private static var didSwizzlePresent = false

    override class func setUp() {
        super.setUp()
        if !didSwizzlePresent {
            UIViewController.test_swizzlePresent()
            didSwizzlePresent = true
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        sut = TodoListViewController()
        presenter = MockPresenter()
        sut.presenter = presenter
        _ = sut.view 
        window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = sut
        window.makeKeyAndVisible()
        PresentationRecorder.lastPresented = nil
    }

    override func tearDown() async throws {
        if sut.presentedViewController != nil {
            sut.dismiss(animated: false)
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        window.isHidden = true
        window = nil
        sut = nil
        presenter = nil
        try await super.tearDown()
    }

    func testShowTodosDisplaysItemsAndUpdatesCount() {
        let viewModel = TodoListItemViewModel(
            id: 1,
            title: "Test",
            details: "Details",
            date: "01/01/25",
            isCompleted: false
        )

        sut.showTodos([viewModel])

        XCTAssertFalse(sut.tableViewForTests.isHidden)
        XCTAssertEqual(sut.tableViewForTests.numberOfRows(inSection: 0), 1)
        XCTAssertEqual(sut.tasksCountLabelForTests.text, "1 Задача")
        XCTAssertTrue(sut.emptyStateLabelForTests.isHidden)
    }

    func testShowEmptyStateHidesTableAndShowsMessage() {
        sut.showEmptyState(message: "Пусто")

        XCTAssertTrue(sut.tableViewForTests.isHidden)
        XCTAssertEqual(sut.emptyStateLabelForTests.text, "Пусто")
        XCTAssertFalse(sut.emptyStateLabelForTests.isHidden)
    }

    func testAddButtonTapDelegatesToPresenter() {
        sut.addButtonForTests.sendActions(for: .touchUpInside)

        XCTAssertTrue(presenter.didTapAddCalled)
    }

    func testRefreshTriggersPresenter() {
        sut.refreshControlForTests.sendActions(for: .valueChanged)

        XCTAssertTrue(presenter.didPullToRefreshCalled)
    }

    func testSearchEditingCallsPresenter() {
        sut.searchTextFieldForTests.text = " query "
        sut.searchTextFieldForTests.sendActions(for: .editingChanged)

        XCTAssertEqual(presenter.updateSearchQueryArguments.last, " query ")
    }

    func testTableViewTrailingActionsInvokePresenter() {
        let viewModel = TodoListItemViewModel(
            id: 7,
            title: "Swipe",
            details: nil,
            date: "02/02/25",
            isCompleted: false
        )
        sut.showTodos([viewModel])

        let tableView = sut.tableViewForTests
        let actions = sut.tableView(
            tableView,
            trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0)
        )

        XCTAssertNotNil(actions)
        XCTAssertEqual(actions?.actions.count, 2)

        let toggleAction = actions!.actions[1]
        toggleAction.handler(toggleAction, UIView(), { _ in })
        XCTAssertTrue(presenter.didToggleCompletionCalled)

        let deleteAction = actions!.actions[0]
        deleteAction.handler(deleteAction, UIView(), { _ in })
        XCTAssertTrue(presenter.didDeleteItemCalled)
    }

    func testTableViewDidSelectNotifiesPresenter() {
        let viewModel = TodoListItemViewModel(
            id: 10,
            title: "Select",
            details: nil,
            date: "03/03/25",
            isCompleted: false
        )
        sut.showTodos([viewModel])

        sut.tableView(sut.tableViewForTests, didSelectRowAt: IndexPath(row: 0, section: 0))

        XCTAssertEqual(presenter.didSelectItemArguments.last, 0)
    }

    func testShowContextMenuPresentsController() async throws {
        let viewModel = TodoContextMenuViewModel(
            title: "Context",
            details: "Details",
            date: "04/04/25",
            isCompleted: false
        )

        sut.showContextMenu(for: viewModel)

        try await waitUntilPresented(TodoContextMenuViewController.self)
        XCTAssertTrue(sut.presentedViewController is TodoContextMenuViewController)
    }

    func testSharePresentsActivityController() async throws {
        sut.share(text: "Some text")

        _ = try await waitUntilPresentationCaptured(UIActivityViewController.self)
    }

    func testShowErrorPresentsAlert() async throws {
        sut.showError(message: "Failure")

        let alert: UIAlertController = try await waitUntilPresentationCaptured(UIAlertController.self)
        XCTAssertEqual(alert.title, "Ошибка")
        XCTAssertEqual(alert.message, "Failure")
    }

    func testScrollViewDidScrollResignsSearchField() {
        sut.searchTextFieldForTests.becomeFirstResponder()

        sut.scrollViewDidScroll(sut.tableViewForTests)

        XCTAssertFalse(sut.searchTextFieldForTests.isFirstResponder)
    }

    func testTextFieldShouldReturnResignsAndUpdatesQuery() {
        sut.searchTextFieldForTests.text = "hello"
        sut.searchTextFieldForTests.becomeFirstResponder()

        let shouldReturn = sut.textFieldShouldReturn(sut.searchTextFieldForTests)

        XCTAssertTrue(shouldReturn)
        XCTAssertFalse(sut.searchTextFieldForTests.isFirstResponder)
        XCTAssertEqual(presenter.updateSearchQueryArguments.last, "hello")
    }

    func testTextFieldShouldReturnHandlesNilText() {
        sut.searchTextFieldForTests.text = nil

        let shouldReturn = sut.textFieldShouldReturn(sut.searchTextFieldForTests)

        XCTAssertTrue(shouldReturn)
        XCTAssertEqual(presenter.updateSearchQueryArguments.last, "")
    }

    func testTableViewMenuAPIReturnsFalse() {
        let indexPath = IndexPath(row: 0, section: 0)
        XCTAssertFalse(sut.tableView(sut.tableViewForTests, shouldShowMenuForRowAt: indexPath))
        XCTAssertFalse(
            sut.tableView(
                sut.tableViewForTests,
                canPerformAction: #selector(UIResponderStandardEditActions.copy(_:)),
                forRowAt: indexPath,
                withSender: nil
            )
        )

        sut.tableView(
            sut.tableViewForTests,
            performAction: #selector(UIResponderStandardEditActions.copy(_:)),
            forRowAt: indexPath,
            withSender: nil
        )
    }

    func testHandleLongPressNotifiesPresenter() {
        let viewModel = TodoListItemViewModel(
            id: 5,
            title: "Long press",
            details: nil,
            date: "05/05/25",
            isCompleted: false
        )
        sut.showTodos([viewModel])
        sut.tableViewForTests.layoutIfNeeded()
        guard let cell = sut.tableViewForTests.cellForRow(at: IndexPath(row: 0, section: 0)) else {
            XCTFail("Cell not found")
            return
        }
        guard let recognizer = cell.gestureRecognizers?.first(where: { $0 is UILongPressGestureRecognizer }) as? UILongPressGestureRecognizer else {
            XCTFail("Long press recognizer missing")
            return
        }
        recognizer.setValue(UIGestureRecognizer.State.began.rawValue, forKey: "state")

        sut.perform(NSSelectorFromString("handleLongPress:"), with: recognizer)

        XCTAssertEqual(presenter.didLongPressItemArguments.last, 0)
    }

    func testVoiceButtonTapWhileListeningStopsRecognition() {
        let audioEngine = MockAudioEngine()
        sut.audioEngineFactory = { audioEngine }
        sut.audioSessionProvider = { MockAudioSession() }
        let recognitionTask = MockRecognitionTask()
        sut.recognitionTaskFactory = { _, _, _ in recognitionTask }
        sut.setAudioEngineForTests(audioEngine)
        sut.setRecognitionTaskForTests(recognitionTask)
        sut.setListeningStateForTests(true)
        sut.setAudioTapInstalledForTests(true)

        sut.voiceButtonForTests.sendActions(for: .touchUpInside)

        XCTAssertTrue(audioEngine.stopCalled)
        XCTAssertTrue(recognitionTask.cancelCalled)
        XCTAssertFalse(sut.isListeningForTests)
    }

    func testRequestSpeechAuthorizationDeniedShowsAlert() async throws {
        let session = MockAudioSession()
        sut.audioSessionProvider = { session }
        sut.speechAuthorizationRequest = { _ in XCTFail("Should not request speech authorization when mic denied") }

        sut.requestSpeechAuthorizationAndStart()
        session.completePermission(granted: false)

        let alert: UIAlertController = try await waitUntilPresentationCaptured(UIAlertController.self)
        XCTAssertEqual(alert.title, "Нет доступа")
    }

    func testSpeechAuthorizationDeniedShowsPermissionAlert() async throws {
        let session = MockAudioSession()
        sut.audioSessionProvider = { session }
        let expectation = expectation(description: "Await permission flow")
        sut.speechAuthorizationRequest = { handler in
            handler(.denied)
            expectation.fulfill()
        }

        sut.requestSpeechAuthorizationAndStart()
        session.completePermission(granted: true)

        await fulfillment(of: [expectation], timeout: 1)

        let alert: UIAlertController = try await waitUntilPresentationCaptured(UIAlertController.self)
        XCTAssertEqual(alert.title, "Нет доступа")
    }

    func testStartVoiceRecognitionWithoutRecognizerShowsError() async throws {
        sut.speechRecognizerFactory = { nil }

        sut.startVoiceRecognition()

        let alert: UIAlertController = try await waitUntilPresentationCaptured(UIAlertController.self)
        XCTAssertEqual(alert.title, "Ошибка")
        XCTAssertEqual(alert.message, "Голосовой ввод недоступен.")
    }

    func testStopVoiceRecognitionRestoresLastRecognizedText() {
        let audioEngine = MockAudioEngine()
        sut.audioEngineFactory = { audioEngine }
        sut.setAudioEngineForTests(audioEngine)
        let session = MockAudioSession()
        sut.audioSessionProvider = { session }
        let recognitionTask = MockRecognitionTask()
        sut.setRecognitionTaskForTests(recognitionTask)
        sut.setListeningStateForTests(true)
        sut.setLastRecognizedTextForTests("  Recognized text  ")
        sut.searchTextFieldForTests.text = " current "
        sut.setAudioTapInstalledForTests(true)

        sut.stopVoiceRecognition()

        XCTAssertEqual(sut.searchTextFieldForTests.text, "  Recognized text  ")
        XCTAssertEqual(presenter.updateSearchQueryArguments.last, "  Recognized text  ")
        XCTAssertTrue(recognitionTask.cancelCalled)
        XCTAssertTrue(audioEngine.stopCalled)
        XCTAssertTrue(session.setActiveCalled)
    }

    func testUpdateVoiceButtonAppearanceReflectsListeningState() {
        sut.voiceButtonForTests.tintColor = .clear
        sut.setListeningStateForTests(true)

        sut.updateVoiceButtonAppearance()

        XCTAssertEqual(sut.voiceButtonForTests.tintColor, .appYellow)

        sut.setListeningStateForTests(false)
        sut.updateVoiceButtonAppearance()

        XCTAssertEqual(sut.voiceButtonForTests.tintColor, UIColor.appWhite.withAlphaComponent(0.5))
    }

    func testContextMenuCallbacksForwardToPresenter() async throws {
        let viewModel = TodoContextMenuViewModel(title: "Item", details: nil, date: "06/06/26", isCompleted: false)

        sut.showContextMenu(for: viewModel)
        let controller: TodoContextMenuViewController = try await waitUntilPresented(TodoContextMenuViewController.self)

        controller.onEdit?()
        controller.onShare?()
        controller.onDelete?()

        XCTAssertEqual(presenter.handleContextActionArguments, [.edit, .share, .delete])
    }

    func testDismissContextMenuClearsPresentation() async throws {
        let viewModel = TodoContextMenuViewModel(
            title: "Context",
            details: nil,
            date: "04/04/25",
            isCompleted: true
        )
        sut.showContextMenu(for: viewModel)
        try await waitUntilPresented(TodoContextMenuViewController.self)

        sut.dismissContextMenu()

        try await waitUntilDismissed()
        XCTAssertNil(sut.presentedViewController)
        XCTAssertTrue(presenter.contextMenuDidDisappearCalled)
    }

    func testStartVoiceRecognitionSuccessConfiguresAudioChain() async throws {
        let recognizer = MockSpeechRecognizer()
        let recognitionTask = MockRecognitionTask()
        recognizer.taskToReturn = recognitionTask
        sut.speechRecognizerFactory = { recognizer }
        sut.setSpeechRecognizerForTests(nil)

        let session = MockAudioSession()
        sut.audioSessionProvider = { session }

        let inputNode = MockAudioInputNode()
        let audioEngine = MockAudioEngine(inputNode: inputNode)
        sut.audioEngineFactory = { audioEngine }

        var capturedHandler: ((String?, Bool, Error?) -> Void)?
        sut.recognitionTaskFactory = { recognizer, request, handler in
            capturedHandler = handler
            return recognizer.startRecognitionTask(with: request) { _, _ in }
        }

        sut.startVoiceRecognition()

        XCTAssertTrue(recognizer.startCalled, "Recognizer should start recognition task")
        XCTAssertNotNil(session.setCategoryParameters, "Audio session category must be configured")
        XCTAssertTrue(audioEngine.prepareCalled, "Audio engine should be prepared")
        XCTAssertTrue(audioEngine.startCalled, "Audio engine should start")
        XCTAssertTrue(sut.isListeningForTests, "Controller should be listening after successful start")
        XCTAssertTrue(inputNode.installTapCalled, "Audio tap must be installed")
        XCTAssertNotNil(capturedHandler, "Recognition handler should be captured")

        capturedHandler?(nil, false, NSError(domain: "test", code: 1))
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(recognitionTask.cancelCalled, "Recognition task should be cancelled on error")
        XCTAssertTrue(audioEngine.stopCalled, "Audio engine should stop on error")
        XCTAssertTrue(session.setActiveCalled, "Audio session should deactivate on stop")
        XCTAssertFalse(sut.isListeningForTests, "Controller should stop listening after error")
    }

    func testDefaultRecognitionTaskFactoryPropagatesRecognizerCallbacks() {
        enum DummyError: Error { case failure }
        let recognizer = MockSpeechRecognizer()
        let recognitionTask = MockRecognitionTask()
        recognizer.taskToReturn = recognitionTask
        sut.speechRecognizerFactory = { recognizer }
        sut.setSpeechRecognizerForTests(nil)

        let session = MockAudioSession()
        sut.audioSessionProvider = { session }

        let inputNode = MockAudioInputNode()
        let audioEngine = MockAudioEngine(inputNode: inputNode)
        sut.audioEngineFactory = { audioEngine }

        let request = MockRecognitionRequest()
        sut.recognitionRequestFactory = { request }

        sut.startVoiceRecognition()

        XCTAssertTrue(recognizer.startCalled)
        XCTAssertNotNil(recognizer.lastResultHandler)

        recognizer.lastResultHandler?(nil, DummyError.failure)
        runMainLoop()

        XCTAssertTrue(request.endAudioCalled)
        XCTAssertTrue(session.setActiveCalled)
        XCTAssertTrue(recognitionTask.cancelCalled)
        XCTAssertFalse(sut.isListeningForTests)
    }

    func testRecognitionTapAppendsAudioBuffer() throws {
        let recognizer = MockSpeechRecognizer()
        recognizer.taskToReturn = MockRecognitionTask()
        sut.speechRecognizerFactory = { recognizer }
        sut.setSpeechRecognizerForTests(nil)

        let session = MockAudioSession()
        sut.audioSessionProvider = { session }

        let inputNode = MockAudioInputNode()
        let audioEngine = MockAudioEngine(inputNode: inputNode)
        sut.audioEngineFactory = { audioEngine }

        let request = MockRecognitionRequest()
        sut.recognitionRequestFactory = { request }

        var capturedHandler: ((String?, Bool, Error?) -> Void)?
        sut.recognitionTaskFactory = { recognizer, request, handler in
            capturedHandler = handler
            return recognizer.startRecognitionTask(with: request) { _, _ in }
        }

        sut.startVoiceRecognition()

        let format = inputNode.outputFormat(forBus: 0)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else {
            XCTFail("Failed to allocate buffer")
            return
        }
        buffer.frameLength = 1
        inputNode.installTapHandler?(buffer, AVAudioTime(hostTime: 0))

        XCTAssertEqual(request.appendedBuffers, 1)
        XCTAssertNotNil(capturedHandler)
    }

    func testRecognitionHandlerDeliversTextAndStopsOnFinalResult() {
        let recognizer = MockSpeechRecognizer()
        recognizer.taskToReturn = MockRecognitionTask()
        sut.speechRecognizerFactory = { recognizer }
        sut.setSpeechRecognizerForTests(nil)

        let session = MockAudioSession()
        sut.audioSessionProvider = { session }

        let audioEngine = MockAudioEngine()
        sut.audioEngineFactory = { audioEngine }

        sut.recognitionRequestFactory = { MockRecognitionRequest() }

        var capturedHandler: ((String?, Bool, Error?) -> Void)?
        sut.recognitionTaskFactory = { recognizer, request, handler in
            capturedHandler = handler
            return recognizer.startRecognitionTask(with: request) { _, _ in }
        }

        sut.startVoiceRecognition()
        XCTAssertNotNil(capturedHandler)

        capturedHandler?("Результат", false, nil)
        runMainLoop()
        XCTAssertEqual(presenter.updateSearchQueryArguments.last, "Результат")

        sut.setListeningStateForTests(true)
        capturedHandler?(nil, true, nil)
        runMainLoop()
        XCTAssertFalse(sut.isListeningForTests)
    }

    func testStartVoiceRecognitionAudioSessionFailureShowsAlert() async throws {
        enum DummyError: Error { case failure }
        let recognizer = MockSpeechRecognizer()
        sut.speechRecognizerFactory = { recognizer }
        sut.setSpeechRecognizerForTests(nil)

        let session = MockAudioSession()
        session.setCategoryError = DummyError.failure
        sut.audioSessionProvider = { session }

        sut.audioEngineFactory = { MockAudioEngine() }
        sut.startVoiceRecognition()

        let alert: UIAlertController = try await waitUntilPresentationCaptured(UIAlertController.self)
        XCTAssertEqual(alert.title, "Ошибка")
        XCTAssertTrue(alert.message?.contains("микрофон") ?? false)
    }

    func testStartVoiceRecognitionAudioEngineFailureShowsAlert() async throws {
        enum DummyError: Error { case failure }
        let recognizer = MockSpeechRecognizer()
        let recognitionTask = MockRecognitionTask()
        recognizer.taskToReturn = recognitionTask
        sut.speechRecognizerFactory = { recognizer }
        sut.setSpeechRecognizerForTests(nil)

        let session = MockAudioSession()
        sut.audioSessionProvider = { session }

        let inputNode = MockAudioInputNode()
        let audioEngine = MockAudioEngine(inputNode: inputNode)
        audioEngine.startError = DummyError.failure
        sut.audioEngineFactory = { audioEngine }
        sut.setAudioEngineForTests(audioEngine)

        sut.startVoiceRecognition()

        let alert: UIAlertController = try await waitUntilPresentationCaptured(UIAlertController.self)
        XCTAssertEqual(alert.title, "Ошибка")
        XCTAssertTrue(alert.message?.contains("запустить запись") ?? false)
        XCTAssertTrue(audioEngine.stopCalled)
        XCTAssertFalse(sut.isListeningForTests)
        XCTAssertNil(PresentationRecorder.lastPresented?.presentedViewController)
    }

    func testHandleRecognizedTextUpdatesSearchAndPresenter() {
        sut.handleRecognizedText("  Привет  ")

        XCTAssertEqual(sut.searchTextFieldForTests.text, "  Привет  ")
        XCTAssertEqual(presenter.updateSearchQueryArguments.last, "  Привет  ")
        XCTAssertEqual(sut.lastRecognizedTextForTests, "  Привет  ")
    }

    func testHandleRecognizedTextIgnoresEmptyString() {
        sut.searchTextFieldForTests.text = "Existing"

        sut.handleRecognizedText("    ")

        XCTAssertEqual(sut.searchTextFieldForTests.text, "Existing")
        XCTAssertNil(sut.lastRecognizedTextForTests)
    }

    func testStopVoiceRecognitionWithoutActiveRecordingDoesNothing() {
        sut.stopVoiceRecognition()

        XCTAssertFalse(presenter.didToggleCompletionCalled)
        XCTAssertFalse(sut.isListeningForTests)
    }

    func testStopVoiceRecognitionEndsInjectedRequest() {
        let request = MockRecognitionRequest()
        let recognitionTask = MockRecognitionTask()
        let inputNode = MockAudioInputNode()
        let audioEngine = MockAudioEngine(inputNode: inputNode)
        sut.audioEngineFactory = { audioEngine }
        sut.setAudioEngineForTests(audioEngine)
        sut.setRecognitionRequestForTests(request)
        sut.setRecognitionTaskForTests(recognitionTask)
        sut.setListeningStateForTests(true)
        sut.setAudioTapInstalledForTests(true)

        sut.stopVoiceRecognition()

        XCTAssertTrue(request.endAudioCalled)
        XCTAssertFalse(sut.isListeningForTests)
        XCTAssertTrue(recognitionTask.cancelCalled)
    }

    func testStopVoiceRecognitionUsesCurrentTextWhenStoredIsEmpty() {
        sut.searchTextFieldForTests.text = " Current "
        sut.setLastRecognizedTextForTests("   ")
        sut.setListeningStateForTests(true)

        sut.stopVoiceRecognition()

        XCTAssertEqual(sut.searchTextFieldForTests.text, " Current ")
        XCTAssertEqual(presenter.updateSearchQueryArguments.last, " Current ")
    }

    func testStopVoiceRecognitionClearsWhenNoTextAvailable() {
        sut.searchTextFieldForTests.text = "   "
        sut.setLastRecognizedTextForTests(nil)
        sut.setListeningStateForTests(true)

        sut.stopVoiceRecognition()

        XCTAssertEqual(sut.searchTextFieldForTests.text, "")
        XCTAssertEqual(presenter.updateSearchQueryArguments.last, "")
    }

    func testToggleHandlerTriggersPresenterAndClearsSuppressedSelection() async throws {
        let viewModel = TodoListItemViewModel(
            id: 11,
            title: "Toggle",
            details: nil,
            date: "07/07/27",
            isCompleted: false
        )
        sut.showTodos([viewModel])
        sut.tableViewForTests.layoutIfNeeded()
        guard let cell = sut.tableViewForTests.cellForRow(at: IndexPath(row: 0, section: 0)) else {
            XCTFail("Cell not available")
            return
        }

        cell.perform(NSSelectorFromString("handleStatusTap"))

        XCTAssertTrue(presenter.didToggleCompletionCalled)
        XCTAssertEqual(sut.suppressSelectionForRowForTests, IndexPath(row: 0, section: 0))

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(sut.suppressSelectionForRowForTests)
    }

    func testCellForRowReturnsFallbackWhenUnexpectedTypeDequeued() {
        sut.tableViewForTests.register(UITableViewCell.self, forCellReuseIdentifier: TodoListTableViewCell.reuseIdentifier)
        let viewModel = TodoListItemViewModel(
            id: 12,
            title: "Fallback",
            details: nil,
            date: "08/08/28",
            isCompleted: false
        )
        sut.showTodos([viewModel])

        let cell = sut.tableView(sut.tableViewForTests, cellForRowAt: IndexPath(row: 0, section: 0))

        XCTAssertFalse(cell is TodoListTableViewCell)
        sut.tableViewForTests.register(TodoListTableViewCell.self, forCellReuseIdentifier: TodoListTableViewCell.reuseIdentifier)
    }

    func testCellForRowWithOutOfRangeIndexReturnsPreparedCell() {
        sut.showTodos([
            TodoListItemViewModel(
                id: 13,
                title: "One",
                details: nil,
                date: "09/09/29",
                isCompleted: false
            )
        ])

        let cell = sut.tableView(sut.tableViewForTests, cellForRowAt: IndexPath(row: 5, section: 0))

        XCTAssertTrue(cell is TodoListTableViewCell)
    }

    func testSearchEditingChangedUpdatesQueryAndKeepsCount() {
        let models = (1...12).map {
            TodoListItemViewModel(id: $0, title: "Item \($0)", details: nil, date: "01/01/25", isCompleted: false)
        }
        sut.showTodos(models)
        XCTAssertEqual(sut.tasksCountLabelForTests.text, "12 Задач")

        sut.searchTextFieldForTests.text = "filter"
        sut.searchTextFieldForTests.sendActions(for: .editingChanged)

        XCTAssertEqual(presenter.updateSearchQueryArguments.last, "filter")
        XCTAssertEqual(sut.tasksCountLabelForTests.text, "12 Задач")
    }

    @discardableResult
    private func waitUntilPresented<T: UIViewController>(
        _ type: T.Type,
        timeout: TimeInterval = 1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> T {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let controller = sut.presentedViewController as? T {
                return controller
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Expected \(T.self) to be presented", file: file, line: line)
        throw WaitError.timeout
    }

    private func waitUntilDismissed(
        timeout: TimeInterval = 1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if sut.presentedViewController == nil {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Expected presented controller to be dismissed", file: file, line: line)
        throw WaitError.timeout
    }

    private func waitUntilPresentationCaptured<T: UIViewController>(
        _ type: T.Type,
        timeout: TimeInterval = 1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> T {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let controller = PresentationRecorder.lastPresented as? T {
                return controller
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Expected \(T.self) to be captured via presentation", file: file, line: line)
        throw WaitError.timeout
    }

    private enum WaitError: Error {
        case timeout
    }

    func runMainLoop(for duration: TimeInterval = 0.1) {
        RunLoop.main.run(until: Date().addingTimeInterval(duration))
    }
}

private enum PresentationRecorder {
    static var lastPresented: UIViewController?
}

private extension UIViewController {
    static func test_swizzlePresent() {
        let originalSelector = #selector(present(_:animated:completion:))
        let swizzledSelector = #selector(test_present(_:animated:completion:))

        guard
            let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
            let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector)
        else { return }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc
    func test_present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        PresentationRecorder.lastPresented = viewControllerToPresent
        test_present(viewControllerToPresent, animated: flag, completion: completion)
    }
}

// Тестовые заглушки и вспомогательные методы

@MainActor
/// Презентер-заглушка, фиксирующая взаимодействия контроллера
private final class MockPresenter: TodoListPresenterProtocol {
    var didTapAddCalled = false
    var didPullToRefreshCalled = false
    var didToggleCompletionCalled = false
    var didDeleteItemCalled = false
    var didSelectItemArguments: [Int] = []
    var updateSearchQueryArguments: [String] = []
    var contextMenuDidDisappearCalled = false
    var didLongPressItemArguments: [Int] = []
    var handleContextActionArguments: [TodoContextAction] = []

    func viewDidLoad() { }
    func didTapAdd() { didTapAddCalled = true }
    func didPullToRefresh() { didPullToRefreshCalled = true }
    func didSelectItem(at index: Int) { didSelectItemArguments.append(index) }
    func didToggleCompletion(at index: Int) { didToggleCompletionCalled = true }
    func didDeleteItem(at index: Int) { didDeleteItemCalled = true }
    func updateSearchQuery(_ query: String) { updateSearchQueryArguments.append(query) }
    func didLongPressItem(at index: Int) { didLongPressItemArguments.append(index) }
    func handleContextAction(_ action: TodoContextAction) { handleContextActionArguments.append(action) }
    func contextMenuDidDisappear() { contextMenuDidDisappearCalled = true }
}

private extension TodoListViewController {
    var tableViewForTests: UITableView {
        mirrorDescendant(for: "tableView")
    }

    var tasksCountLabelForTests: UILabel {
        mirrorDescendant(for: "tasksCountLabel")
    }

    var emptyStateLabelForTests: UILabel {
        mirrorDescendant(for: "emptyStateLabel")
    }

    var addButtonForTests: UIButton {
        mirrorDescendant(for: "addButton")
    }

    var refreshControlForTests: UIRefreshControl {
        mirrorDescendant(for: "refreshControl")
    }

    var searchTextFieldForTests: UITextField {
        mirrorDescendant(for: "searchTextField")
    }

    var voiceButtonForTests: UIButton {
        mirrorDescendant(for: "voiceButton")
    }

    /// Возвращает приватное свойство контроллера по имени через отражение
    func mirrorDescendant<T>(for label: String) -> T {
        var mirror: Mirror? = Mirror(reflecting: self)
        while let currentMirror = mirror {
            if let value = currentMirror.children.first(where: { $0.label == label })?.value as? T {
                return value
            }
            mirror = currentMirror.superclassMirror
        }
        fatalError("Property \(label) not found")
    }
}

// Заглушки, имитирующие голосовое распознавание и аудио

/// Имитация AVAudioSession для тестирования сценариев голосового ввода
private final class MockAudioSession: NSObject, AudioSessionProtocol {
    private var permissionHandler: ((Bool) -> Void)?
    var setCategoryParameters: (AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)?
    private(set) var setActiveCalled = false
    var setCategoryError: Error?
    var setActiveError: Error?

    func requestRecordPermission(_ handler: @escaping (Bool) -> Void) {
        permissionHandler = handler
    }

    func completePermission(granted: Bool) {
        permissionHandler?(granted)
    }

    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        if let error = setCategoryError {
            throw error
        }
        setCategoryParameters = (category, mode, options)
    }

    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        if let error = setActiveError {
            throw error
        }
        setActiveCalled = true
    }
}

/// Подмена AVAudioEngine, позволяющая контролировать жизненный цикл записи
private final class MockAudioEngine: NSObject, AudioEngineProtocol {
    let inputNodeWrapper: AudioInputNodeProtocol
    private(set) var prepareCalled = false
    private(set) var startCalled = false
    private(set) var stopCalled = false
    var startError: Error?

    init(inputNode: AudioInputNodeProtocol = MockAudioInputNode()) {
        self.inputNodeWrapper = inputNode
    }

    func prepare() {
        prepareCalled = true
    }

    func start() throws {
        startCalled = true
        if let startError {
            throw startError
        }
    }

    func stop() {
        stopCalled = true
    }
}

/// Тестовый входной узел аудиосессии, отслеживающий установки tap
private final class MockAudioInputNode: NSObject, AudioInputNodeProtocol {
    private(set) var removeTapCalled = false
    private(set) var installTapCalled = false
    var installTapHandler: AVAudioNodeTapBlock?

    func outputFormat(forBus bus: AVAudioNodeBus) -> AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    }

    func removeTap(onBus bus: AVAudioNodeBus) {
        removeTapCalled = true
    }

    func installTap(
        onBus bus: AVAudioNodeBus,
        bufferSize: AVAudioFrameCount,
        format: AVAudioFormat?,
        block: @escaping AVAudioNodeTapBlock
    ) {
        installTapCalled = true
        installTapHandler = block
    }
}

/// Заглушка буферного запроса распознавания речи
private final class MockRecognitionRequest: SFSpeechAudioBufferRecognitionRequest {
    private(set) var appendedBuffers = 0
    private(set) var endAudioCalled = false

    override func append(_ buffer: AVAudioPCMBuffer) {
        appendedBuffers += 1
        super.append(buffer)
    }

    override func endAudio() {
        endAudioCalled = true
        super.endAudio()
    }
}

/// Тестовая задача распознавания, фиксирующая вызов cancel
private final class MockRecognitionTask: NSObject, SpeechRecognitionTaskProtocol {
    private(set) var cancelCalled = false

    func cancel() {
        cancelCalled = true
    }
}

/// Имитация распознавателя речи, позволяющая управлять результатами
private final class MockSpeechRecognizer: NSObject, SpeechRecognizerProtocol {
    var isAvailable: Bool = true
    private(set) var startCalled = false
    private(set) var lastRequest: SFSpeechRecognitionRequest?
    var taskToReturn: SpeechRecognitionTaskProtocol = MockRecognitionTask()
    private(set) var lastResultHandler: ((SFSpeechRecognitionResult?, Error?) -> Void)?

    func startRecognitionTask(
        with request: SFSpeechRecognitionRequest,
        resultHandler: @escaping (SFSpeechRecognitionResult?, Error?) -> Void
    ) -> SpeechRecognitionTaskProtocol {
        startCalled = true
        lastRequest = request
        lastResultHandler = resultHandler
        return taskToReturn
    }
}

