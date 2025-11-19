//
//  TodoListTableViewCellTests.swift
//  To-DoTests
//
//  Created by Anton Solovev on 11.11.2025.
//

import XCTest
@testable import To_Do

/// Проверяем отображение и поведение ячейки списка задач
@MainActor
final class TodoListTableViewCellTests: XCTestCase {
    private var cell: TodoListTableViewCell!

    override func setUp() async throws {
        try await super.setUp()
        cell = TodoListTableViewCell(style: .default, reuseIdentifier: nil)
        cell.frame = CGRect(x: 0, y: 0, width: 320, height: 88)
        cell.layoutIfNeeded()
    }

    override func tearDown() async throws {
        cell = nil
        try await super.tearDown()
    }


    private func makeEmptyCoder() throws -> NSKeyedUnarchiver {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.encode(0, forKey: "dummy")
        archiver.finishEncoding()
        let coder = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        coder.requiresSecureCoding = false
        return coder
    }

    /// Завершённая задача получает зачёркнутый текст и чекбокс
    func testConfigureForCompletedTodoAppliesStrikeThroughAndAccessibility() throws {
        let viewModel = TodoListItemViewModel(
            id: 1,
            title: "Написать отчёт",
            details: "Сдать до 18:00",
            date: "11.11.2025",
            isCompleted: true
        )

        cell.configure(with: viewModel)

        let titleLabel: UILabel = try cell.element(named: "titleLabel")
        let detailsLabel: UILabel = try cell.element(named: "detailsLabel")
        let dateLabel: UILabel = try cell.element(named: "dateLabel")
        let statusButton: UIButton = try cell.element(named: "statusButton")

        let attributed = try XCTUnwrap(titleLabel.attributedText)
        let strikeValue = attributed.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(strikeValue, NSUnderlineStyle.single.rawValue)
        XCTAssertEqual(statusButton.accessibilityValue, "completed")
        XCTAssertNotNil(statusButton.image(for: .normal))
        XCTAssertFalse(detailsLabel.isHidden)
        XCTAssertEqual(detailsLabel.text, viewModel.details)
        XCTAssertEqual(dateLabel.text, viewModel.date)
    }

    /// Активная задача не зачёркивается и скрывает пустое описание
    func testConfigureForActiveTodoShowsPlainTitleAndHidesDetailsWhenMissing() throws {
        let viewModel = TodoListItemViewModel(
            id: 2,
            title: "Позвонить клиенту",
            details: nil,
            date: "12.11.2025",
            isCompleted: false
        )

        cell.configure(with: viewModel)

        let titleLabel: UILabel = try cell.element(named: "titleLabel")
        let detailsLabel: UILabel = try cell.element(named: "detailsLabel")
        let statusButton: UIButton = try cell.element(named: "statusButton")

        XCTAssertEqual(titleLabel.text, viewModel.title)
        if let attributed = titleLabel.attributedText, attributed.length > 0 {
            let strikeValue = attributed.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
            XCTAssertNotEqual(strikeValue, NSUnderlineStyle.single.rawValue, "Active item should not have strikethrough")
        }
        XCTAssertTrue(detailsLabel.isHidden)
        XCTAssertNil(statusButton.image(for: .normal))
        XCTAssertEqual(statusButton.accessibilityValue, "active")
    }

    /// prepareForReuse возвращает ячейку в исходное состояние
    func testPrepareForReuseResetsVisualState() throws {
        let viewModel = TodoListItemViewModel(
            id: 3,
            title: "Закрыть задачу",
            details: "Удалить из списка",
            date: "13.11.2025",
            isCompleted: true
        )
        cell.configure(with: viewModel)
        cell.prepareForReuse()

        let titleLabel: UILabel = try cell.element(named: "titleLabel")
        let detailsLabel: UILabel = try cell.element(named: "detailsLabel")
        let statusButton: UIButton = try cell.element(named: "statusButton")
        let separator: UIView = try cell.element(named: "separatorView")

        XCTAssertNil(titleLabel.attributedText)
        XCTAssertNil(titleLabel.text)
        XCTAssertFalse(detailsLabel.isHidden, "prepareForReuse should restore default visibility")
        XCTAssertNil(statusButton.image(for: .normal))
        XCTAssertEqual(statusButton.accessibilityValue, nil)
        XCTAssertFalse(separator.isHidden)
    }

    /// Флаг separator управляет видимостью разделительной линии
    func testSetShowsSeparatorUpdatesVisibility() throws {
        let separator: UIView = try cell.element(named: "separatorView")

        cell.setShowsSeparator(false)
        XCTAssertTrue(separator.isHidden)

        cell.setShowsSeparator(true)
        XCTAssertFalse(separator.isHidden)
    }

    /// Обработчик переключения вызывается при нажатии на статус
    func testToggleHandlerInvokesClosureOnTap() throws {
        let statusButton: UIButton = try cell.element(named: "statusButton")
        var toggleCount = 0

        cell.setToggleHandler {
            toggleCount += 1
        }

        statusButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(toggleCount, 1)
    }

    /// hitTest расширяет активную область кнопки статуса
    func testHitTestExpandsStatusButtonTouchArea() throws {
        let statusButton: UIButton = try cell.element(named: "statusButton")
        cell.layoutIfNeeded()

        let externalPoint = CGPoint(
            x: statusButton.frame.minX - 6,
            y: statusButton.frame.midY
        )
        let hitView = cell.hitTest(externalPoint, with: nil)

        XCTAssertTrue(hitView === statusButton, "hitTest should return status button for points slightly outside its bounds")
    }

    func testInitWithCoderInitializesSubviews() throws {
        let coder = try makeEmptyCoder()
        defer { coder.finishDecoding() }
        let coderCell = try XCTUnwrap(TodoListTableViewCell(coder: coder))
        coderCell.layoutIfNeeded()

        let _: UILabel = try coderCell.element(named: "titleLabel")
        let _: UIButton = try coderCell.element(named: "statusButton")
    }

    /// Когда details есть, detailsLabel.isHidden устанавливается в false
    func testConfigureWithDetailsShowsDetailsLabel() throws {
        let viewModel = TodoListItemViewModel(
            id: 4,
            title: "Task with details",
            details: "Some details text",
            date: "14.11.2025",
            isCompleted: false
        )

        cell.configure(with: viewModel)

        let detailsLabel: UILabel = try cell.element(named: "detailsLabel")
        XCTAssertFalse(detailsLabel.isHidden, "Details label should be visible when details are provided")
        XCTAssertEqual(detailsLabel.text, "Some details text")
    }

    /// hitTest возвращает super.hitTest для точек вне расширенной области кнопки
    func testHitTestReturnsSuperForPointsOutsideButtonArea() throws {
        cell.layoutIfNeeded()
        let statusButton: UIButton = try cell.element(named: "statusButton")
        
        // Точка внутри bounds ячейки, но далеко от кнопки (справа от кнопки)
        // Кнопка находится слева (leadingAnchor + 20), поэтому точка справа не должна попадать в расширенную область
        let farPoint = CGPoint(
            x: cell.bounds.width - 10,  // Правая часть ячейки
            y: cell.bounds.midY
        )
        let hitView = cell.hitTest(farPoint, with: nil)
        
        // Должен вернуться результат super.hitTest (обычно contentView или сама ячейка)
        XCTAssertNotNil(hitView)
        XCTAssertFalse(hitView === statusButton, "Points far from button should not hit the button")
    }
}

// Вспомогательный доступ к приватным свойствам ячейки

private extension TodoListTableViewCell {
    func element<T>(named name: String) throws -> T {
        var mirror: Mirror? = Mirror(reflecting: self)
        while let current = mirror {
            if let value = current.children.first(where: { $0.label == name })?.value as? T {
                return value
            }
            mirror = current.superclassMirror
        }
        throw NSError(domain: "TodoListTableViewCellTests", code: 0, userInfo: [NSLocalizedDescriptionKey: "Property \(name) not found"])
    }
}

