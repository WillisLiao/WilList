import XCTest

/// The flows that must never break, driven the way a student would: add a to-do and tick it off,
/// add the day's A1 from Today, set a reminder on one and Mark done on the reminder when it comes,
/// give one a letter, Mark done on the A1 card at the top of Today, a focus session on it, the
/// first-run welcome, Plan tomorrow (from Plan and from Today's evening card) and Search.
/// Each test starts the app from a known plan in a file of its own (`-plan`, see TestPlan.swift).
@MainActor
final class CoreFlowsTests: XCTestCase {
    /// How long to wait for something to appear or go. A wait ends as soon as it does, so passing
    /// runs are no slower; a busy CI machine once took over 5 seconds to open the letter sorter,
    /// while one look at the screen there took 20.
    private let wait: TimeInterval = 15

    func testAddATodoAndTickItOff() {
        let app = launch(plan: "empty")
        add("Buy stamps", in: app)
        app.buttons["Mark done"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Completed"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.buttons["Done"].exists, "the to-do's circle is filled")
    }

    func testAddTheA1FromToday() {
        let app = launch(plan: "empty")
        // Before anything has a letter, Today asks what matters most, and adding it starts with an A.
        XCTAssertTrue(app.staticTexts["What matters most today?"].waitForExistence(timeout: wait))
        app.buttons["Add your A1"].tap()
        let field = app.textFields["What and when"]
        XCTAssertTrue(field.waitForExistence(timeout: wait))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'A:'")).firstMatch.isSelected, "A is chosen")
        field.typeText("Write the essay intro\n")
        app.navigationBars.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["markA1Done"].waitForExistence(timeout: wait), "it leads the day on the A1 card")
        XCTAssertTrue(title("Write the essay intro", in: app).exists)
    }

    func testSetAReminderOnATodo() {
        let app = launch(plan: "empty")
        add("Call the dentist", in: app)
        app.staticTexts["Call the dentist"].tap()
        let remind = app.buttons["Remind me"]
        XCTAssertTrue(remind.waitForExistence(timeout: wait))
        remind.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tomorrow'")).firstMatch.tap()
        allowNotifications()
        XCTAssertTrue(app.staticTexts["Remind me at 9:00\u{202F}AM"].waitForExistence(timeout: wait)
                      || app.staticTexts["Remind me at 9:00 AM"].exists)
    }

    func testMarkDoneFromAReminder() {
        let app = launch(plan: "reminder")
        allowNotifications()
        XCTAssertTrue(app.staticTexts["Return the lab goggles"].waitForExistence(timeout: wait))
        // The reminder comes while the app waits in the background, where Mark done once stopped it.
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let banner = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Return the lab goggles'")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 90), "the reminder comes")
        banner.press(forDuration: 1.5)
        let done = springboard.buttons["Mark done"]
        XCTAssertTrue(done.waitForExistence(timeout: wait))
        done.tap()
        app.activate()
        XCTAssertTrue(app.staticTexts["Completed"].waitForExistence(timeout: wait), "the to-do is done")
        XCTAssertTrue(app.buttons["Done"].exists, "the to-do's circle is filled")
    }

    func testGiveATodoALetter() {
        let app = launch(plan: "empty")
        add("Email the TA", in: app)
        app.staticTexts["Email the TA"].tap()
        let give = app.buttons["Give it a letter"]
        XCTAssertTrue(give.waitForExistence(timeout: wait))
        give.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Must do'")).firstMatch.tap()
        // Back on Today it is the A1, on the card.
        XCTAssertTrue(app.buttons["markA1Done"].waitForExistence(timeout: wait))
        XCTAssertTrue(title("Email the TA", in: app).exists)
    }

    func testMarkTheA1Done() {
        let app = launch(plan: "a1")
        XCTAssertTrue(title("Write the essay intro", in: app).waitForExistence(timeout: wait))
        // Undo first, the moment its message shows: on a slow machine, checking anything else
        // before it can outlast the message.
        let undo = app.buttons["Undo"]
        XCTAssertTrue(tap(app.buttons["markA1Done"]) { undo.waitForExistence(timeout: wait) }, "Mark done offers Undo")
        undo.tap()
        XCTAssertTrue(gone(title("Read chapter 4", in: app)), "the essay intro is back in the card")
        XCTAssertTrue(title("Write the essay intro", in: app).exists)
        // Done again: the next A moves up into the card and the finished one leaves Today.
        app.buttons["markA1Done"].tap()
        XCTAssertTrue(title("Read chapter 4", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(gone(title("Write the essay intro", in: app)))
        // The last A done, the card says so.
        app.buttons["markA1Done"].tap()
        XCTAssertTrue(app.staticTexts["Your A’s are done."].waitForExistence(timeout: wait), "the card says the A’s are done")
    }

    func testFocusOnTheA1() {
        let app = launch(plan: "a1")
        app.buttons["Start"].tap()
        XCTAssertTrue(app.staticTexts["One thing. Stay with it until it’s done."].waitForExistence(timeout: wait))
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: wait))
        app.buttons["focusDone"].tap()
        // The focus screen closes on Today, where the next A has moved up into the card.
        XCTAssertTrue(gone(title("Write the essay intro", in: app)))
        XCTAssertTrue(title("Read chapter 4", in: app).exists)
    }

    func testFirstRunPicksAnA1() {
        let app = launch(plan: "new")
        let first = app.textFields["Read chapter 4 by Monday"]
        XCTAssertTrue(first.waitForExistence(timeout: wait))
        first.tap()
        first.typeText("Write the lab report\n")
        app.textFields["And next?"].typeText("Email Prof. Chen\n")
        app.buttons["Next"].tap()
        choose(app.buttons["Write the lab report"], in: app)
        app.buttons["Make it my A1"].tap()
        app.buttons["Start"].tap()
        XCTAssertTrue(app.buttons["markA1Done"].waitForExistence(timeout: wait), "Today opens on the A1 card")
        XCTAssertTrue(title("Write the lab report", in: app).exists)
        // The other line waits for a letter, one tap away.
        app.buttons["1 waiting for a letter"].tap()
        XCTAssertTrue(app.staticTexts["Email Prof. Chen"].waitForExistence(timeout: wait))
        app.buttons["B, Should do. Mild consequences"].tap()
        XCTAssertTrue(app.staticTexts["All lettered"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["Your A1 is \u{201C}Write the lab report\u{201D}."].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(gone(app.buttons["1 waiting for a letter"]))
    }

    func testPlanTomorrowPicksTheA1() {
        let app = launch(plan: "a1", tab: "plan")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Plan tomorrow'")).firstMatch.tap()
        let field = app.textFields["Read chapter 5 by Friday"]
        XCTAssertTrue(field.waitForExistence(timeout: wait), "Plan tomorrow opens on its first step")
        field.typeText("Buy a lab notebook\n")
        app.buttons["Next"].tap()
        // Tomorrow's list, its A1 already chosen; the other A becomes the A1 instead.
        choose(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Read chapter 4'")).firstMatch, in: app)
        app.buttons["Make it my A1"].tap()
        XCTAssertTrue(app.staticTexts["Tomorrow starts with"].waitForExistence(timeout: wait), "it ends on tomorrow's A1")
        XCTAssertTrue(title("Read chapter 4", in: app).exists, "the chosen one is tomorrow's A1")
        XCTAssertTrue(app.staticTexts["1 still waits for a letter."].exists, "the line written waits for a letter")
        app.buttons["Done"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(title("Read chapter 4", in: app).waitForExistence(timeout: wait), "Today's card shows the new A1")
        XCTAssertFalse(title("Write the essay intro", in: app).exists, "only the A1 shows on Today")
    }

    func testPlanTomorrowFromTheEveningCard() {
        let app = launch(plan: "empty", night: true)
        // In the evening, with nothing left for today, Today turns to tomorrow.
        XCTAssertTrue(app.staticTexts["What matters most tomorrow?"].waitForExistence(timeout: wait))
        app.buttons["Plan tomorrow"].tap()
        let field = app.textFields["Read chapter 5 by Friday"]
        XCTAssertTrue(field.waitForExistence(timeout: wait), "Plan tomorrow opens on its first step")
        field.typeText("Buy a lab notebook\n")
        app.buttons["Next"].tap()
        choose(app.buttons["Buy a lab notebook"], in: app)
        app.buttons["Make it my A1"].tap()
        XCTAssertTrue(app.staticTexts["Tomorrow starts with"].waitForExistence(timeout: wait))
        app.buttons["Done"].tap()
        // Back on Today the line leads the card: with no date, it counts from now on.
        XCTAssertTrue(gone(app.staticTexts["What matters most tomorrow?"]))
        XCTAssertTrue(title("Buy a lab notebook", in: app).exists, "the new A1 is on the card")
    }

    func testSearchFindsATodo() {
        let app = launch(plan: "busy")
        app.buttons["Search"].tap()
        // Ready to type as soon as it opens: typing fails unless the field has the keyboard.
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: wait))
        field.typeText("stamps")
        app.buttons["Buy stamps"].tap()
        let details = app.navigationBars["To-do"]
        XCTAssertTrue(details.waitForExistence(timeout: wait))
        details.buttons["Done"].tap()
        XCTAssertTrue(gone(details), "the to-do's details close")
        // The X beside the field closes Search.
        XCTAssertTrue(tap(app.buttons["Close"]) { gone(field) }, "the X closes Search")
        XCTAssertTrue(app.textFields["Add a to-do"].exists)
    }

    // MARK: helpers

    /// Starts the app on a known plan; `night` makes it evening, past the planning time.
    private func launch(plan: String, tab: String = "today", night: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plan", plan, "-tab", tab, "-playSound", "NO", "-focus", "NO", "-night", night ? "YES" : "NO"]
        app.launch()
        return app
    }

    /// Types a line into Today's "Add a to-do" and presses return.
    private func add(_ line: String, in app: XCUIApplication) {
        let field = app.textFields["Add a to-do"]
        XCTAssertTrue(field.waitForExistence(timeout: wait))
        field.tap()
        field.typeText("\(line)\n")
        XCTAssertTrue(app.staticTexts[line].waitForExistence(timeout: wait))
    }

    /// Answers the notification permission prompt, the first time there is one. Allow is its
    /// second button in every language the simulator may run in.
    private func allowNotifications() {
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if alert.waitForExistence(timeout: 3) { alert.buttons.element(boundBy: 1).tap() }
    }

    /// Taps, then waits for what the tap should do (`happened` waits up to five seconds). A CI
    /// simulator now and then loses a tap: on 2026-10-22 one landed dead centre on Mark done and the
    /// app never saw it, and another hit Search's X while the bar was still sliding it into place.
    /// A tap with nothing to show for it is tried once more.
    private func tap(_ button: XCUIElement, until happened: () -> Bool) -> Bool {
        button.tap()
        if happened() { return true }
        button.tap()
        return happened()
    }

    /// A to-do or item title as it shows. A title set large may join its last two words with a
    /// no-break space (`Fmt.noWidow`), so it matches either way. (A regular expression did too, but
    /// took 20 seconds on a busy CI machine.)
    private func title(_ text: String, in app: XCUIApplication) -> XCUIElement {
        var joined = text
        if let last = text.lastIndex(of: " ") { joined.replaceSubrange(last...last, with: "\u{00A0}") }
        return app.staticTexts.matching(NSPredicate(format: "label IN %@", [text, joined])).firstMatch
    }

    private func gone(_ element: XCUIElement) -> Bool {
        element.waitForNonExistence(timeout: wait)
    }

    /// Picks a row on a "which one first" page. Next has just swapped the page in and sent the
    /// keyboard down, so let both settle first: a tap while the rows still move can land on
    /// another row, and the old A1 stays chosen.
    private func choose(_ row: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(gone(app.keyboards.firstMatch), "the keyboard goes down")
        XCTAssertTrue(row.waitForExistence(timeout: wait), "the row is there")
        row.tap()
        XCTAssertTrue(row.wait(for: \.isSelected, toEqual: true, timeout: wait), "the row tapped is the one chosen")
    }
}
