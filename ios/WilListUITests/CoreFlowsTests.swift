import XCTest

/// The flows that must never break, driven the way a student would: add a to-do and tick it off,
/// add the day's A1 in Plan, set a reminder on one and Mark done on the reminder when it comes,
/// give one a letter, tick off the A1 at the top of Today, a focus session on it, the first-run
/// welcome, Plan tomorrow from Today's evening nudge, Search, and adding what the Agent found.
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
        XCTAssertTrue(tap(app.buttons["Mark done"].firstMatch, shows: app.staticTexts["Completed"]))
        XCTAssertTrue(app.buttons["Done"].exists, "the to-do's circle is filled")
    }

    func testAddTheA1InPlan() {
        let app = launch(plan: "empty", tab: "plan")
        let field = app.textFields["What and when"]
        XCTAssertTrue(tap(app.navigationBars.buttons["Add"], shows: app.buttons["Task"]))
        XCTAssertTrue(tap(app.buttons["Task"], shows: field))
        wait(for: [expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)], timeout: wait)
        field.typeText("Write the essay intro")
        let a = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'A:'")).firstMatch
        XCTAssertTrue(tap(a) { a.wait(for: \.isSelected, toEqual: true, timeout: wait) }, "A is chosen")
        // "essay" reads as a deadline, so the sheet may be New deadline.
        let sheet = app.navigationBars.matching(NSPredicate(format: "identifier BEGINSWITH 'New'")).firstMatch
        XCTAssertTrue(tap(sheet.buttons["Add"], shows: sheet.buttons["Done"]))
        XCTAssertTrue(tap(sheet.buttons["Done"], hides: sheet))
        // It leads Today, with Play for a focus session on it.
        XCTAssertTrue(tap(app.buttons["tab-today"], shows: app.buttons["Start a focus session"].firstMatch), "it leads the day")
        XCTAssertTrue(title("Write the essay intro", in: app).exists)
    }

    func testSetAReminderOnATodo() {
        let app = launch(plan: "empty")
        add("Call the dentist", in: app)
        let remind = app.buttons["Remind me"]
        XCTAssertTrue(tap(title("Call the dentist", in: app), shows: remind))
        let tomorrow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tomorrow'")).firstMatch
        XCTAssertTrue(tap(remind, shows: tomorrow))
        tomorrow.tap()
        allowNotifications()
        XCTAssertTrue(app.staticTexts["Remind me at 9:00\u{202F}AM"].waitForExistence(timeout: wait)
                      || app.staticTexts["Remind me at 9:00 AM"].exists)
    }

    func testMarkDoneFromAReminder() {
        let app = launch(plan: "reminder")
        allowNotifications()
        XCTAssertTrue(title("Return the lab goggles", in: app).waitForExistence(timeout: wait))
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
        let give = app.buttons["Give it a letter"]
        XCTAssertTrue(tap(title("Email the TA", in: app), shows: give))
        let mustDo = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Must do'")).firstMatch
        XCTAssertTrue(tap(give, shows: mustDo))
        // Back on Today it is the A1, at the top.
        XCTAssertTrue(tap(mustDo, shows: app.buttons["Start a focus session"].firstMatch))
        XCTAssertTrue(title("Email the TA", in: app).exists)
    }

    func testMarkTheA1Done() {
        let app = launch(plan: "a1")
        XCTAssertTrue(title("Write the essay intro", in: app).waitForExistence(timeout: wait))
        // Undo first, the moment its message shows: on a slow machine, checking anything else
        // before it can outlast the message.
        let undo = app.buttons["Undo"], tick = app.buttons["Mark done"].firstMatch
        XCTAssertTrue(tap(tick) { undo.waitForExistence(timeout: wait) }, "ticking it off offers Undo")
        undo.tap()
        XCTAssertTrue(gone(title("Read chapter 4", in: app)), "the essay intro is the A1 again")
        XCTAssertTrue(title("Write the essay intro", in: app).exists)
        // Done again: the next A moves up and the finished one leaves Today.
        XCTAssertTrue(tap(tick, shows: title("Read chapter 4", in: app)))
        XCTAssertTrue(gone(title("Write the essay intro", in: app)))
        // The last A done, the day is clear.
        let clear = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'All clear'")).firstMatch
        XCTAssertTrue(tap(tick, shows: clear), "the day says it's clear")
    }

    func testFocusOnTheA1() {
        let app = launch(plan: "a1")
        // Play asks how long.
        XCTAssertTrue(tap(app.buttons["Start a focus session"].firstMatch, shows: app.buttons["25 min"]))
        XCTAssertTrue(tap(app.buttons["25 min"], shows: app.staticTexts["One thing until it’s done."]))
        XCTAssertTrue(tap(app.buttons["Pause"], shows: app.buttons["Resume"]))
        // The focus screen closes on Today, where the next A has moved up.
        XCTAssertTrue(tap(app.buttons["focusDone"], hides: title("Write the essay intro", in: app)))
        XCTAssertTrue(title("Read chapter 4", in: app).exists)
    }

    func testFirstRunPicksAnA1() {
        let app = launch(plan: "new")
        let first = app.textFields["Read chapter 4 by Monday"]
        XCTAssertTrue(first.waitForExistence(timeout: wait))
        first.tap()
        first.typeText("Write the lab report\n")
        app.textFields["And next?"].typeText("Email Prof. Chen\n")
        XCTAssertTrue(tap(app.buttons["Next"], shows: app.buttons["Make it my A1"]))
        choose(app.buttons["Write the lab report"], in: app)
        XCTAssertTrue(tap(app.buttons["Make it my A1"], shows: app.buttons["Start"]))
        XCTAssertTrue(tap(app.buttons["Start"], shows: app.textFields["Add a to-do"]), "Today opens")
        XCTAssertTrue(title("Write the lab report", in: app).exists)
        // The other line waits in Plan, with no letter and nothing asking for one.
        XCTAssertTrue(tap(app.buttons["tab-plan"], shows: title("Email Prof. Chen", in: app)))
        XCTAssertFalse(app.buttons["Give it a letter"].exists, "no mark without a letter")
    }

    func testPlanTomorrowPicksTheA1() {
        let app = launch(plan: "a1", night: true)
        let planTomorrow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Plan tomorrow'")).firstMatch
        let field = app.textFields["Read chapter 5 by Friday"]
        XCTAssertTrue(tap(planTomorrow, shows: field), "Plan tomorrow opens on its first step")
        field.typeText("Buy a lab notebook\n")
        XCTAssertTrue(tap(app.buttons["Next"], shows: app.buttons["Make it my A1"]))
        // Tomorrow's list, its A1 already chosen; the other A becomes the A1 instead.
        choose(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Read chapter 4'")).firstMatch, in: app)
        XCTAssertTrue(tap(app.buttons["Make it my A1"], shows: app.staticTexts["Tomorrow starts with"]), "it ends on tomorrow's A1")
        XCTAssertTrue(title("Read chapter 4", in: app).exists, "the chosen one is tomorrow's A1")
        XCTAssertTrue(tap(app.buttons["Done"], hides: app.staticTexts["Tomorrow starts with"]))
        XCTAssertTrue(title("Read chapter 4", in: app).exists, "Today leads with the new A1")
        XCTAssertFalse(title("Write the essay intro", in: app).exists, "only the A1 shows on Today")
    }

    func testPlanTomorrowFromAnEmptyDay() {
        let app = launch(plan: "empty", night: true)
        // In the evening, Today offers to plan tomorrow.
        let planTomorrow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Plan tomorrow'")).firstMatch
        XCTAssertTrue(planTomorrow.waitForExistence(timeout: wait))
        let field = app.textFields["Read chapter 5 by Friday"]
        XCTAssertTrue(tap(planTomorrow, shows: field), "Plan tomorrow opens on its first step")
        field.typeText("Buy a lab notebook\n")
        XCTAssertTrue(tap(app.buttons["Next"], shows: app.buttons["Make it my A1"]))
        choose(app.buttons["Buy a lab notebook"], in: app)
        XCTAssertTrue(tap(app.buttons["Make it my A1"], shows: app.staticTexts["Tomorrow starts with"]))
        // Back on Today the line leads: with no date, it counts from now on.
        XCTAssertTrue(tap(app.buttons["Done"], hides: app.staticTexts["Tomorrow starts with"]))
        XCTAssertTrue(title("Buy a lab notebook", in: app).exists, "the new A1 leads Today")
    }

    func testSearchFindsATodo() {
        let app = launch(plan: "busy")
        // Ready to type as soon as it opens: typing fails unless the field has the keyboard, which a
        // slow CI simulator hands it a moment after the field shows (it failed a run on 2026-10-24).
        let field = app.searchFields.firstMatch
        XCTAssertTrue(tap(app.buttons["Search"], shows: field))
        wait(for: [expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)], timeout: wait)
        field.typeText("stamps")
        let details = app.navigationBars["To-do"]
        // Today's row is a button of the same name under the sheet: tap the one that can be.
        let found = app.buttons.matching(identifier: "Buy stamps")
        XCTAssertTrue(found.element(boundBy: 1).waitForExistence(timeout: wait))
        let result = found.allElementsBoundByIndex.first(where: \.isHittable) ?? found.firstMatch
        XCTAssertTrue(tap(result, shows: details))
        XCTAssertTrue(tap(details.buttons["Done"], hides: details), "the to-do's details close")
        // The X beside the field closes Search.
        XCTAssertTrue(tap(app.buttons["Close"]) { gone(field) }, "the X closes Search")
        XCTAssertTrue(app.textFields["Add a to-do"].exists)
    }

    func testTheAgentAddsOnlyWhatIsTicked() {
        // The Agent answers from its script (`AgentDemo`): no server, key or subscription.
        let app = launch(plan: "busy", tab: "agent", more: ["-agentDemo", "YES", "-agentConsent", "YES"])
        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: wait))
        XCTAssertTrue(tap(field, shows: app.keyboards.firstMatch), "the field takes the keyboard")
        field.typeText("Here's my syllabus")
        let add = app.buttons["Add 3"]
        XCTAssertTrue(tap(app.buttons["Send"], shows: add), "the Agent proposes three things")
        let reading = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Read chapter 7'")).firstMatch
        XCTAssertTrue(tap(reading, shows: app.buttons["Add 2"]), "unticking one leaves two")
        XCTAssertTrue(tap(app.buttons["Add 2"], shows: app.staticTexts["Added 2 items"]))
        // Undo takes them out again, and the card offers them again.
        XCTAssertTrue(tap(app.buttons["Undo"], shows: app.buttons["Add 2"]), "Undo brings the button back")
    }

    // MARK: helpers

    /// Starts the app on a known plan; `night` makes it evening, past the planning time.
    private func launch(plan: String, tab: String = "today", night: Bool = false, more: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plan", plan, "-tab", tab, "-playSound", "NO", "-focus", "NO", "-night", night ? "YES" : "NO"] + more
        app.launch()
        return app
    }

    /// Types a line into Today's "Add a to-do" and presses return.
    private func add(_ line: String, in app: XCUIApplication) {
        let field = app.textFields["Add a to-do"]
        XCTAssertTrue(field.waitForExistence(timeout: wait))
        XCTAssertTrue(tap(field, shows: app.keyboards.firstMatch), "the field takes the keyboard")
        field.typeText("\(line)\n")
        XCTAssertTrue(title(line, in: app).waitForExistence(timeout: wait))
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

    /// Taps, tried once more if `result` hasn't appeared (see above): every tap that opens or
    /// changes a screen goes through here, as a lost one failed a run on 2026-10-23 too.
    private func tap(_ button: XCUIElement, shows result: XCUIElement) -> Bool {
        tap(button) { result.waitForExistence(timeout: wait) }
    }

    /// Taps, tried once more if `result` hasn't gone.
    private func tap(_ button: XCUIElement, hides result: XCUIElement) -> Bool {
        tap(button) { gone(result) }
    }

    /// A to-do or item title as it shows. A title set large may join its last two words with a
    /// no-break space (`Fmt.noWidow`), so it matches either way. (A regular expression did too, but
    /// took 20 seconds on a busy CI machine.)
    private func title(_ text: String, in app: XCUIApplication) -> XCUIElement {
        var joined = text
        if let last = text.lastIndex(of: " ") { joined.replaceSubrange(last...last, with: "\u{00A0}") }
        // A row's words are one button, its line after the title ("Read chapter 4, Due Fri").
        return app.descendants(matching: .any)
            .matching(NSPredicate(format: "label IN %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@", [text, joined], text + ",", joined + ","))
            .firstMatch
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
        XCTAssertTrue(tap(row) { row.wait(for: \.isSelected, toEqual: true, timeout: wait) }, "the row tapped is the one chosen")
    }
}
