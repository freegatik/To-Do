//
//  To_DoUITests.swift
//  To-DoUITests
//
//  Created by Anton Solovev on 07.11.2025.
//

import XCTest

/// UI-сценарии: создаём, редактируем, удаляем и ищем задачи
final class To_DoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @discardableResult
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        if app.state == .runningForeground || app.state == .runningBackground {
            app.terminate()
        }
        var arguments = app.launchArguments
        arguments.append("--uitest")
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func createTask(app: XCUIApplication, title: String, details: String) {
        let addButton = app.buttons["todoList.addButton"]
        guard require(addButton.waitForExistence(timeout: 5), message: "Кнопка добавления недоступна.") else { return }
        addButton.tap()

        let titleField = app.textViews["editor.title"]
        guard require(titleField.waitForExistence(timeout: 5), message: "Поле заголовка редактора отсутствует.") else { return }
        titleField.tap()
        titleField.typeText(title)

        let bodyField = app.textViews["editor.body"]
        guard require(bodyField.waitForExistence(timeout: 5), message: "Поле описания редактора отсутствует.") else { return }
        bodyField.tap()
        bodyField.typeText(details)

        let backButton = app.buttons["editor.back"]
        guard require(backButton.waitForExistence(timeout: 2), message: "Кнопка возврата недоступна.") else { return }
        backButton.tap()

        let listAddButton = app.buttons["todoList.addButton"]
        require(listAddButton.waitForExistence(timeout: 8), message: "Редактор должен закрыться и вернуть список задач.")
    }

    func testCreateTaskFlow() {
        let app = launchApp()
        createTask(app: app, title: "UI Create", details: "Описание создания")

        let table = app.tables["todoList.table"]
        require(table.waitForExistence(timeout: 5), message: "Таблица задач должна вернуться на экран.")
        waitForCell(in: table, withTitle: "UI Create", shouldExist: true)
    }

    func testEditTaskUpdatesList() {
        let app = launchApp()
        createTask(app: app, title: "UI Edit", details: "Нужно обновить")

        let table = app.tables["todoList.table"]
        guard require(table.waitForExistence(timeout: 5), message: "Таблица задач должна быть доступна.") else { return }
        let cell = table.cells.element(boundBy: 0)
        guard require(cell.waitForExistence(timeout: 5), message: "Первая ячейка должна появиться.") else { return }
        cell.tap()

        let titleField = app.textViews["editor.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.replaceText(with: "UI Edit Updated")

        app.buttons["editor.back"].tap()
        let editorDismissed = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: app.buttons["editor.back"],
            handler: nil
        )
        wait(for: [editorDismissed], timeout: 5)

        waitForCell(in: table, withTitle: "UI Edit Updated", shouldExist: true)
    }

    func testDeleteTaskFromContextMenu() {
        let app = launchApp()
        createTask(app: app, title: "UI Delete", details: "Удалить через меню")

        let table = app.tables["todoList.table"]
        guard require(table.waitForExistence(timeout: 5), message: "Таблица задач должна быть доступна.") else { return }
        let cell = table.cells.element(boundBy: 0)
        guard require(cell.waitForExistence(timeout: 5), message: "Ячейка для удаления должна существовать.") else { return }
        cell.press(forDuration: 0.6)

        let deleteButton = app.buttons["context.delete"]
        guard require(deleteButton.waitForExistence(timeout: 5), message: "Кнопка удаления в меню недоступна.") else { return }
        deleteButton.tap()
        let menuDismissed = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: deleteButton,
            handler: nil
        )
        wait(for: [menuDismissed], timeout: 5)
        waitForCell(in: table, withTitle: "UI Delete", shouldExist: false, timeout: 12)
    }

    func testContextMenuShowsActions() {
        let app = launchApp()
        createTask(app: app, title: "UI Menu", details: "Контекстное меню")

        let table = app.tables["todoList.table"]
        guard require(table.waitForExistence(timeout: 5), message: "Таблица задач должна быть доступна.") else { return }
        let cell = table.cells.element(boundBy: 0)
        guard require(cell.waitForExistence(timeout: 5), message: "Ячейка для меню должна существовать.") else { return }
        cell.press(forDuration: 0.6)

        let editButton = app.buttons["context.edit"]
        let shareButton = app.buttons["context.share"]
        let deleteButton = app.buttons["context.delete"]

        require(editButton.waitForExistence(timeout: 5), message: "Кнопка редактирования недоступна.")
        require(shareButton.waitForExistence(timeout: 5), message: "Кнопка поделиться недоступна.")
        require(deleteButton.waitForExistence(timeout: 5), message: "Кнопка удаления недоступна.")

        deleteButton.tap()
    }

    func testSearchFiltersTasks() {
        let app = launchApp()
        createTask(app: app, title: "Alpha Task", details: "Первый")
        createTask(app: app, title: "Bravo Task", details: "Второй")

        let searchContainer = app.otherElements["todoList.searchContainer"]
        guard require(searchContainer.waitForExistence(timeout: 5), message: "Контейнер поиска должен быть доступен на экране списка.") else { return }

        let searchField = searchContainer.textFields["todoList.searchField"]
        guard require(searchField.waitForExistence(timeout: 2), message: "Поле поиска должно быть доступно на экране списка.") else { return }
        searchField.tap()
        searchField.typeText("Alpha")

        let table = app.tables["todoList.table"]
        waitForCell(in: table, withTitle: "Alpha Task", shouldExist: true)
        waitForCell(in: table, withTitle: "Bravo Task", shouldExist: false)

        searchField.clearText()
        searchField.typeText("Нет такой")

        let emptyState = app.staticTexts["todoList.emptyState"]
        require(emptyState.waitForExistence(timeout: 5), message: "При отсутствии задач должно отображаться пустое состояние.")
    }
}

private extension XCUIElement {
    /// Удаляет текущий текст элемента и печатает новый
    func clearText() {
        tap()
        let deleteString: String
        if let currentValue = value as? String, !currentValue.isEmpty {
            deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        } else {
            deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: 40)
        }
        typeText(deleteString)
    }

    /// Заменяет текст элемента на переданный
    func replaceText(with text: String) {
        tap()
        press(forDuration: 1.0)
        let app = XCUIApplication()
        let selectAllEnglish = app.menuItems["Select All"]
        let selectAllRussian = app.menuItems["Выделить всё"]

        if selectAllRussian.waitForExistence(timeout: 1) {
            selectAllRussian.tap()
        } else if selectAllEnglish.waitForExistence(timeout: 1) {
            selectAllEnglish.tap()
        } else {
            clearText()
        }

        typeText(text)
    }

}

private extension To_DoUITests {
    @discardableResult
    func require(
        _ condition: @autoclosure () -> Bool,
        message: @autoclosure () -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let result = condition()
        let failureMessage = message()
        if !result {
            XCTFail(failureMessage, file: file, line: line)
        }
        return result
    }

    /// Ожидаем появления или исчезновения ячейки с заданным заголовком
    func waitForCell(in table: XCUIElement, withTitle title: String, shouldExist: Bool, timeout: TimeInterval = 8) {
        let cell = table.cells.containing(.staticText, identifier: title).element
        let predicate = NSPredicate(format: "exists == %@", NSNumber(value: shouldExist))
        let expectation = expectation(for: predicate, evaluatedWith: cell, handler: nil)
        wait(for: [expectation], timeout: timeout)
        if shouldExist {
            require(cell.exists, message: "Ячейка \(title) должна отображаться.")
        } else {
            require(!cell.exists, message: "Ячейка \(title) не должна отображаться.")
        }
    }
}
