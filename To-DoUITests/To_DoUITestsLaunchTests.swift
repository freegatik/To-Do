//
//  To_DoUITestsLaunchTests.swift
//  To-DoUITests
//
//  Created by Anton Solovev on 07.11.2025.
//

import XCTest

final class To_DoUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Добавьте действия, которые нужно выполнить после запуска приложения и перед созданием скриншота,
        // например, авторизацию тестового пользователя или переход к нужному экрану.

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
