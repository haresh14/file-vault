import XCTest

final class FileVaultUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testFirstLaunchAuthenticationSelection() {
        let app = launch(arguments: ["--ui-testing-first-launch"])

        XCTAssertTrue(app.buttons["auth.choice.passcode4"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["auth.choice.passcode6"].exists)
        XCTAssertTrue(app.buttons["auth.choice.password"].exists)

        app.buttons["auth.choice.passcode6"].tap()
        app.buttons["auth.continue"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .tap()

        XCTAssertTrue(app.buttons["keypad.1"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testTabSwitchingAndBasicNavigation() {
        let app = launchAuthenticated()
        let tabs = app.buttons

        XCTAssertTrue(tabs["tab.folder"].firstMatch.waitForExistence(timeout: 5))
        tabs["tab.category"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 3))

        tabs["tab.gallery"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Gallery"].waitForExistence(timeout: 3))

        tabs["tab.webUpload"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Web Upload"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["webUpload.toggleServer"].exists)

        tabs["tab.settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        let screenshotProtection = app.switches["settings.screenshotProtection"]
        for _ in 0..<3 where !screenshotProtection.exists {
            app.swipeUp()
        }
        XCTAssertTrue(screenshotProtection.waitForExistence(timeout: 3))
    }

    @MainActor
    func testFakeVaultRestrictsWebUploadAndSettings() {
        let app = launchAuthenticated(fakeLogin: true)
        let tabs = app.buttons

        tabs["tab.webUpload"].firstMatch.tap()
        XCTAssertTrue(app.buttons["webUpload.serverDisabled"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Web server is not available in this mode"].exists)

        tabs["tab.settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.switches["settings.screenshotProtection"].exists)
        XCTAssertTrue(app.staticTexts["Version"].exists)
    }

    @MainActor
    func testGalleryAddControlsAreReachable() {
        let app = launchAuthenticated()
        app.buttons["tab.gallery"].firstMatch.tap()

        app.buttons["vault.actions"].tap()
        app.buttons["Add Files"].tap()

        XCTAssertTrue(app.staticTexts["Add Content"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["add.photos-videos"].exists)
        XCTAssertTrue(app.buttons["add.files"].exists)
        XCTAssertTrue(app.buttons["add.web-upload"].exists)
    }

    @MainActor
    private func launchAuthenticated(fakeLogin: Bool = false) -> XCUIApplication {
        let arguments = fakeLogin ? ["--ui-testing-fake-login"] : []
        let app = launch(arguments: arguments)
        let passcode = fakeLogin ? "9876" : "1234"
        passcode.forEach { digit in
            let button = app.buttons["keypad.\(digit)"]
            button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertTrue(app.buttons["tab.folder"].firstMatch.waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func launch(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + arguments
        app.launch()
        return app
    }
}
