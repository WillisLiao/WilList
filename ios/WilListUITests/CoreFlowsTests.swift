import XCTest

/// The flows that must never break, driven the way a student would: add a to-do and tick it off,
/// set a reminder on one, Mark done on the A1 card at the top of Today, and the first-run welcome.
/// Each test starts the app from a known plan in a file of its own (`-plan`, see TestPlan.swift).
@MainActor
final class CoreFlowsTests: XCTestCase {
    func testAddATodoAndTickItOff() {
        let app = launch(plan: "empty")
        add("Buy stamps", in: app)
        app.buttons["Mark done"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Completed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists, "the to-do's circle is filled")
        XCTAssertTrue(app.staticTexts["All clear, 1 done today."].exists)
    }

    func testSetAReminderOnATodo() {
        let app = launch(plan: "empty")
        add("Call the dentist", in: app)
        app.staticTexts["Call the dentist"].tap()
        let remind = app.buttons["Remind me"]
        XCTAssertTrue(remind.waitForExistence(timeout: 5))
        remind.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tomorrow'")).firstMatch.tap()
        allowNotifications()
        XCTAssertTrue(app.staticTexts["Remind me at 9:00\u{202F}AM"].waitForExistence(timeout: 5)
                      || app.staticTexts["Remind me at 9:00 AM"].exists)
    }

    func testMarkTheA1Done() {
        let app = launch(plan: "a1")
        XCTAssertTrue(app.staticTexts["Write the essay intro"].waitForExistence(timeout: 5))
        app.buttons["markA1Done"].tap()
        // The next A moves up into the card, the finished one leaves Today, and Undo brings it back.
        XCTAssertTrue(gone(app.staticTexts["Write the essay intro"]))
        XCTAssertTrue(app.staticTexts["Read chapter 4"].exists)
        XCTAssertTrue(app.buttons["markA1Done"].exists)
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.staticTexts["Write the essay intro"].waitForExistence(timeout: 5))
    }

    func testFirstRunPicksAnA1() {
        let app = launch(plan: "new")
        let first = app.textFields["Read chapter 4 by Monday"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        first.typeText("Write the lab report\n")
        app.textFields["And next?"].typeText("Email Prof. Chen\n")
        app.buttons["Next"].tap()
        app.buttons["Write the lab report"].tap()
        app.buttons["Make it my A1"].tap()
        app.buttons["Start"].tap()
        XCTAssertTrue(app.buttons["markA1Done"].waitForExistence(timeout: 5), "Today opens on the A1 card")
        XCTAssertTrue(app.staticTexts["Write the lab report"].exists)
        // The other line waits for a letter in Plan, one tap away.
        app.buttons["1 waiting for a letter in Plan"].tap()
        XCTAssertTrue(app.staticTexts["Email Prof. Chen"].waitForExistence(timeout: 5))
    }

    // MARK: helpers

    private func launch(plan: String, tab: String = "today") -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plan", plan, "-tab", tab, "-playSound", "NO"]
        app.launch()
        return app
    }

    /// Types a line into Today's "Add a to-do" and presses return.
    private func add(_ line: String, in app: XCUIApplication) {
        let field = app.textFields["Add a to-do"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("\(line)\n")
        XCTAssertTrue(app.staticTexts[line].waitForExistence(timeout: 5))
    }

    /// Answers the notification permission prompt, the first time there is one. Allow is its
    /// second button in every language the simulator may run in.
    private func allowNotifications() {
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout: 3) { alert.buttons.element(boundBy: 1).tap() }
    }

    private func gone(_ element: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
    }
}
