//
//  To_DoUITests.swift
//  To-DoUITests
//
//  Created by Anton Solovev on 07.11.2025.
//

import XCTest

/// Простые UI-тесты, проверяем что экран открывается
final class To_DoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testListScreenHasBaseElements() throws {
        let app = XCUIApplication()
        app.launch()

        let navigationBar = app.navigationBars["Задачи"]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5), "Не удалось найти заголовок экрана.")

        let table = app.tables["todoList.table"]
        XCTAssertTrue(table.waitForExistence(timeout: 5), "Таблица задач недоступна.")

        let searchField = app.searchFields["Поиск задач"]
        XCTAssertTrue(searchField.exists, "Строка поиска должна быть видимой.")

        let hasCell = table.cells.element(boundBy: 0).waitForExistence(timeout: 5)
        let emptyState = app.staticTexts["todoList.emptyState"].exists
        XCTAssertTrue(hasCell || emptyState, "Ожидалось наличие задачи или заглушки пустого состояния.")
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
