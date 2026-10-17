import XCTest

/// Covers the most important funnel in the game: launch → first challenge → first stamp → home.
final class FirstSessionUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
        return app
    }

    func testFirstTrailCompletesInUnderThirtySecondsAndLandsOnHome() {
        let app = launch()
        let start = Date()

        app.buttons["startFirstTrail"].tap()
        let field = app.textFields["guessField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Rome")
        app.buttons["Rome, Italy"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["resultsTitle"].waitForExistence(timeout: 5))
        XCTAssertLessThan(Date().timeIntervalSince(start), 30, "First win must land inside 30 seconds")

        app.buttons["resultsPrimary"].tap()
        XCTAssertTrue(app.buttons["finishOnboarding"].waitForExistence(timeout: 3))
        app.buttons["finishOnboarding"].tap()
        XCTAssertTrue(app.buttons["playDaily"].waitForExistence(timeout: 3))
    }

    func testWrongGuessRevealsNextClue() {
        let app = launch()
        app.buttons["startFirstTrail"].tap()
        let field = app.textFields["guessField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Tokyo")
        app.buttons["Tokyo, Japan"].firstMatch.tap()
        let clue2 = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Clue 2 of 5")).firstMatch
        XCTAssertTrue(clue2.waitForExistence(timeout: 3))
    }

    func testCanLeaveRoundAndResume() {
        let app = launch()
        app.buttons["startFirstTrail"].tap()
        XCTAssertTrue(app.buttons["closeRound"].waitForExistence(timeout: 3))
        app.buttons["closeRound"].tap()
        XCTAssertTrue(app.buttons["startFirstTrail"].waitForExistence(timeout: 3))
    }
}
