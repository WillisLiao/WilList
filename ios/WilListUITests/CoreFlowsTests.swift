import XCTest

/// The flows that must never break, driven the way a student would: add a to-do and tick it off,
/// set a reminder on one, give one a letter, Mark done on the A1 card at the top of Today, a focus
/// session on it, the first-run welcome, Plan tomorrow and Search.
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

    func testGiveATodoALetter() {
        let app = launch(plan: "empty")
        add("Email the TA", in: app)
        app.staticTexts["Email the TA"].tap()
        let give = app.buttons["Give it a letter"]
        XCTAssertTrue(give.waitForExistence(timeout: 5))
        give.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Must do'")).firstMatch.tap()
        // Back on Today it is the A1, on the card.
        XCTAssertTrue(app.buttons["markA1Done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Email the TA"].exists)
    }

    func testMarkTheA1Done() {
        let app = launch(plan: "a1")
        XCTAssertTrue(app.staticTexts["Write the essay intro"].waitForExistence(timeout: 5))
        // Undo first, the moment its message shows: on a slow machine, checking anything else
        // before it can outlast the message.
        let undo = app.buttons["Undo"]
        XCTAssertTrue(tap(app.buttons["markA1Done"], until: undo), "Mark done offers Undo")
        undo.tap()
        XCTAssertTrue(gone(app.staticTexts["Read chapter 4"]), "the essay intro is back in the card")
        XCTAssertTrue(app.staticTexts["Write the essay intro"].exists)
        // Done again: the next A moves up into the card and the finished one leaves Today.
        app.buttons["markA1Done"].tap()
        XCTAssertTrue(app.staticTexts["Read chapter 4"].waitForExistence(timeout: 5))
        XCTAssertTrue(gone(app.staticTexts["Write the essay intro"]))
    }

    func testFocusOnTheA1() {
        let app = launch(plan: "a1")
        app.buttons["Start"].tap()
        XCTAssertTrue(app.staticTexts["One thing. Stay with it until it’s done."].waitForExistence(timeout: 5))
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 5))
        app.buttons["focusDone"].tap()
        // The focus screen closes on Today, where the next A has moved up into the card.
        XCTAssertTrue(gone(app.staticTexts["Write the essay intro"]))
        XCTAssertTrue(app.staticTexts["Read chapter 4"].exists)
    }

    func testFirstRunPicksAnA1() {
        let app = launch(plan: "new")
        let first = app.textFields["Read chapter 4 by Monday"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        first.typeText("Write the lab report\n")
        app.textFields["And next?"].typeText("Email Prof. Chen\n")
        app.buttons["Next"].tap()
        choose(app.buttons["Write the lab report"], in: app)
        app.buttons["Make it my A1"].tap()
        app.buttons["Start"].tap()
        XCTAssertTrue(app.buttons["markA1Done"].waitForExistence(timeout: 5), "Today opens on the A1 card")
        XCTAssertTrue(app.staticTexts["Write the lab report"].exists)
        // The other line waits for a letter, one tap away.
        app.buttons["1 waiting for a letter"].tap()
        XCTAssertTrue(app.staticTexts["Email Prof. Chen"].waitForExistence(timeout: 5))
        app.buttons["B, Should do. Mild consequences"].tap()
        XCTAssertTrue(app.staticTexts["All lettered"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your A1 is \u{201C}Write the lab report\u{201D}."].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(gone(app.buttons["1 waiting for a letter"]))
    }

    func testPlanTomorrowPicksTheA1() {
        let app = launch(plan: "a1", tab: "plan")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Plan tomorrow'")).firstMatch.tap()
        let field = app.textFields["Read chapter 5 by Friday"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Plan tomorrow opens on its first step")
        field.typeText("Buy a lab notebook\n")
        app.buttons["Next"].tap()
        // Tomorrow's list, its A1 already chosen; the other A becomes the A1 instead.
        choose(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Read chapter 4'")).firstMatch, in: app)
        app.buttons["Make it my A1"].tap()
        XCTAssertTrue(app.staticTexts["Tomorrow starts with"].waitForExistence(timeout: 5), "it ends on tomorrow's A1")
        XCTAssertTrue(app.staticTexts["Read chapter 4"].exists, "the chosen one is tomorrow's A1")
        XCTAssertTrue(app.staticTexts["1 still waits for a letter."].exists, "the line written waits for a letter")
        app.buttons["Done"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.staticTexts["Read chapter 4"].waitForExistence(timeout: 5), "Today's card shows the new A1")
        XCTAssertFalse(app.staticTexts["Write the essay intro"].exists, "only the A1 shows on Today")
    }

    func testSearchFindsATodo() {
        let app = launch(plan: "busy")
        app.buttons["Search"].tap()
        // Ready to type as soon as it opens: typing fails unless the field has the keyboard.
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("stamps")
        app.buttons["Buy stamps"].tap()
        let details = app.navigationBars["To-do"]
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        details.buttons["Done"].tap()
        // The X beside the field closes Search.
        app.buttons["Close"].tap()
        XCTAssertTrue(gone(field))
        XCTAssertTrue(app.textFields["Add a to-do"].exists)
    }

    // MARK: helpers

    private func launch(plan: String, tab: String = "today") -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plan", plan, "-tab", tab, "-playSound", "NO", "-focus", "NO", "-night", "NO"]
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

    /// Taps, then waits for what the tap brings up. A CI simulator now and then drops a tap: on
    /// 2026-10-22 one landed dead centre on Mark done and the app never saw it (no press, nothing
    /// changed). A tap with nothing to show for it after five seconds is tried once more.
    private func tap(_ button: XCUIElement, until shown: XCUIElement) -> Bool {
        button.tap()
        if shown.waitForExistence(timeout: 5) { return true }
        button.tap()
        return shown.waitForExistence(timeout: 5)
    }

    private func gone(_ element: XCUIElement) -> Bool {
        element.waitForNonExistence(timeout: 5)
    }

    /// Picks a row on a "which one first" page. Next has just swapped the page in and sent the
    /// keyboard down, so let both settle first: a tap while the rows still move can land on
    /// another row, and the old A1 stays chosen.
    private func choose(_ row: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(gone(app.keyboards.firstMatch), "the keyboard goes down")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the row is there")
        row.tap()
        XCTAssertTrue(row.wait(for: \.isSelected, toEqual: true, timeout: 5), "the row tapped is the one chosen")
    }
}
