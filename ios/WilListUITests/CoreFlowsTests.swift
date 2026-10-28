import XCTest

/// The flows that must never break, driven the way a student would: add a to-do and tick it off,
/// add the day's A1 in Plan, set a reminder on one (or while adding it in Plan) and Mark done on the reminder when it comes,
/// give one a letter, tick off the A1 at the top of Today, a focus session on it that leaves it to do, Plan tomorrow as the evening notice opens it, Search, and adding what the Agent found.
/// Each test starts the app from a known plan in a file of its own (`-plan`, see TestPlan.swift).
@MainActor
final class CoreFlowsTests: XCTestCase {
    /// How long to wait for something to appear or go. A wait ends as soon as it does, so passing
    /// runs are no slower; a busy CI machine once took over 5 seconds to open the letter sorter,
    /// while one look at the screen there took 20.
    private let wait: TimeInterval = 15

    /// Return only puts the keyboard away; Add at the top right adds the line.
    func testAddATodoAndTickItOff() {
        let app = launch(plan: "empty")
        let field = app.textFields["Add a to-do"]
        XCTAssertTrue(field.waitForExistence(timeout: wait))
        XCTAssertTrue(tap(field, shows: app.keyboards.firstMatch), "the field takes the keyboard")
        field.typeText("Buy stamps\n")
        XCTAssertTrue(app.navigationBars.buttons["Add"].waitForExistence(timeout: wait))
        XCTAssertFalse(title("Buy stamps", in: app).exists, "return doesn't add it")
        XCTAssertTrue(tap(app.navigationBars.buttons["Add"], shows: title("Buy stamps", in: app)))
        XCTAssertTrue(tap(app.buttons["Mark done"].firstMatch, shows: app.staticTexts["Completed"]))
        XCTAssertTrue(app.buttons["Done"].exists, "the to-do's circle is filled")
    }

    /// Today's line takes a letter and a reminder before it's added, and Add adds it.
    func testAddALetteredTaskOnToday() {
        let app = launch(plan: "empty")
        let field = app.textFields["Add a to-do"]
        XCTAssertTrue(field.waitForExistence(timeout: wait))
        XCTAssertTrue(tap(field, shows: app.keyboards.firstMatch), "the field takes the keyboard")
        field.typeText("Read chapter 2")
        let a = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'A:'")).firstMatch
        XCTAssertTrue(tap(a) { a.wait(for: \.isSelected, toEqual: true, timeout: wait) }, "A is chosen")
        let tomorrow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tomorrow'")).firstMatch
        XCTAssertTrue(tap(app.buttons["Reminder"], shows: tomorrow))
        tomorrow.tap()
        allowNotifications()
        XCTAssertTrue(tap(app.navigationBars.buttons["Add"], shows: app.buttons["Start a focus session"].firstMatch), "it leads Today")
        XCTAssertTrue(title("Read chapter 2", in: app).exists)
        // The keyboard covers the tab bar; return on the empty line puts it away.
        field.typeText("\n")
        XCTAssertTrue(app.buttons["tab-plan"].waitForExistence(timeout: wait), "the tab bar is back")
        XCTAssertTrue(tap(app.buttons["tab-plan"], shows: app.buttons["Letter A, Must do. Change"]), "it's an A in Plan")
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
        let sheet = app.navigationBars["New task"]
        XCTAssertTrue(tap(sheet.buttons["Add"], shows: sheet.buttons["Done"]))
        XCTAssertTrue(tap(sheet.buttons["Done"], hides: sheet))
        // It leads the day in Plan, with Play for a focus session on it, and stays off Today.
        XCTAssertTrue(title("Write the essay intro", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(app.buttons["Letter A, Must do. Change"].exists, "it's an A")
        XCTAssertTrue(app.buttons["Start a focus session"].firstMatch.exists)
        XCTAssertTrue(tap(app.buttons["tab-today"], shows: app.textFields["Add a to-do"]))
        XCTAssertFalse(title("Write the essay intro", in: app).exists, "Plan's tasks stay off Today")
    }

    /// A deleted to-do waits in Settings' Trash, and Restore puts it back on Today.
    func testRestoreADeletedTodo() {
        let app = launch(plan: "empty")
        add("Buy stamps", in: app)
        let row = title("Buy stamps", in: app)
        row.swipeLeft()
        XCTAssertTrue(tap(app.buttons["Delete"], hides: row), "it leaves Today")
        let trash = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Trash'")).firstMatch
        XCTAssertTrue(tap(app.buttons["Settings"].firstMatch, shows: app.navigationBars["Settings"]))
        // The Trash is under Backup, below the first screenful.
        app.swipeUp()
        XCTAssertTrue(trash.waitForExistence(timeout: wait))
        XCTAssertTrue(tap(trash, shows: app.buttons["Restore Buy stamps"]), "it waits in the trash")
        XCTAssertTrue(tap(app.buttons["Restore Buy stamps"], hides: app.buttons["Restore Buy stamps"]))
        XCTAssertTrue(app.staticTexts["Nothing here"].waitForExistence(timeout: wait))
        XCTAssertTrue(tap(app.navigationBars.buttons["Settings"].firstMatch, shows: app.buttons["Done"]))
        XCTAssertTrue(tap(app.buttons["Done"], shows: row), "it's back on Today")
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

    /// New task in Plan has Remind me, the date and Repeat, so nothing waits until it's added.
    func testSetAReminderWhileAddingInPlan() {
        let app = launch(plan: "empty", tab: "plan")
        let field = app.textFields["What and when"]
        XCTAssertTrue(tap(app.navigationBars.buttons["Add"], shows: app.buttons["Task"]))
        XCTAssertTrue(tap(app.buttons["Task"], shows: field))
        wait(for: [expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)], timeout: wait)
        field.typeText("Email the TA")
        let tomorrow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tomorrow'")).firstMatch
        XCTAssertTrue(tap(app.buttons["Remind me"], shows: tomorrow))
        tomorrow.tap()
        allowNotifications()
        let set = NSPredicate(format: "label BEGINSWITH 'Remind me at 9:00'")
        XCTAssertTrue(app.staticTexts.matching(set).firstMatch.waitForExistence(timeout: wait))
        let sheet = app.navigationBars["New task"]
        XCTAssertTrue(tap(sheet.buttons["Add"], shows: sheet.buttons["Done"]))
        XCTAssertTrue(tap(sheet.buttons["Done"], hides: sheet))
        XCTAssertTrue(tap(title("Email the TA", in: app), shows: app.staticTexts.matching(set).firstMatch), "the reminder was saved")
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

    /// Only what was added to Today shows there: Plan's other A never moves up into its place.
    func testTickATaskAddedToToday() {
        let app = launch(plan: "a1")
        XCTAssertTrue(title("Write the essay intro", in: app).waitForExistence(timeout: wait))
        XCTAssertFalse(title("Read chapter 4", in: app).exists, "Plan's other A stays in Plan")
        // Undo first, the moment its message shows: on a slow machine, checking anything else
        // before it can outlast the message.
        let undo = app.buttons["Undo"], tick = app.buttons["Mark done"].firstMatch
        XCTAssertTrue(tap(tick) { undo.waitForExistence(timeout: wait) }, "ticking it off offers Undo")
        undo.tap()
        XCTAssertTrue(title("Write the essay intro", in: app).waitForExistence(timeout: wait), "Undo brings it back")
        // Done again: it leaves Today, and the day is clear.
        let clear = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'All clear'")).firstMatch
        XCTAssertTrue(tap(tick, shows: clear), "the day says it's clear")
        XCTAssertTrue(gone(title("Write the essay intro", in: app)))
        XCTAssertFalse(title("Read chapter 4", in: app).exists, "nothing comes up from Plan")
    }

    func testFocusOnATaskOnToday() {
        let app = launch(plan: "a1")
        // Play asks how long.
        XCTAssertTrue(tap(app.buttons["Start a focus session"].firstMatch, shows: app.buttons["25 min"]))
        XCTAssertTrue(tap(app.buttons["25 min"], shows: app.staticTexts["One thing until it’s done."]))
        XCTAssertTrue(tap(app.buttons["Pause"], shows: app.buttons["Resume"]))
        // The chevron lowers the screen: the task is still to do, its Play button now shows the time
        // left, and tapping that brings the timer back.
        XCTAssertTrue(tap(app.buttons["Minimize"], shows: title("Write the essay intro", in: app)))
        let running = app.buttons["Timer running"].firstMatch
        XCTAssertTrue(running.waitForExistence(timeout: wait))
        XCTAssertTrue(tap(running, shows: app.buttons["Open timer"]))
        XCTAssertTrue(tap(app.buttons["Open timer"], shows: app.buttons["Resume"]), "the paused timer is still there")
        XCTAssertFalse(title("Read chapter 4", in: app).exists, "nothing comes up from Plan")
    }

    func testPlanTomorrowPicksTheA1() {
        // As the evening notice opens it.
        let app = launch(plan: "a1", more: ["-evening", "1"])
        let field = app.textFields["Read chapter 5 by Friday"]
        XCTAssertTrue(field.waitForExistence(timeout: wait), "Plan tomorrow opens on its first step")
        wait(for: [expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)], timeout: wait)
        field.typeText("Buy a lab notebook\n")
        XCTAssertTrue(tap(app.buttons["Next"], shows: app.buttons["Make it my A1"]))
        // Tomorrow's list, its A1 already chosen; the other A becomes the A1 instead.
        choose(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Read chapter 4'")).firstMatch, in: app)
        XCTAssertTrue(tap(app.buttons["Make it my A1"], shows: app.staticTexts["Tomorrow starts with"]), "it ends on tomorrow's A1")
        XCTAssertTrue(title("Read chapter 4", in: app).exists, "the chosen one is tomorrow's A1")
        // Back on Today, tomorrow's A1 waits for tomorrow; what was added to Today stays.
        XCTAssertTrue(tap(app.buttons["Done"], hides: app.staticTexts["Tomorrow starts with"]))
        XCTAssertTrue(title("Write the essay intro", in: app).exists, "today's task stays on Today")
        XCTAssertFalse(title("Read chapter 4", in: app).exists, "tomorrow's A1 isn't on Today yet")
    }

    func testPlanTomorrowFromAnEmptyDay() {
        let app = launch(plan: "empty", more: ["-evening", "1"])
        let field = app.textFields["Read chapter 5 by Friday"]
        XCTAssertTrue(field.waitForExistence(timeout: wait), "Plan tomorrow opens on its first step")
        wait(for: [expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)], timeout: wait)
        field.typeText("Buy a lab notebook\n")
        XCTAssertTrue(tap(app.buttons["Next"], shows: app.buttons["Make it my A1"]))
        choose(app.buttons["Buy a lab notebook"], in: app)
        XCTAssertTrue(tap(app.buttons["Make it my A1"], shows: app.staticTexts["Tomorrow starts with"]))
        // It waits in Plan, and on Today from tomorrow.
        XCTAssertTrue(tap(app.buttons["Done"], hides: app.staticTexts["Tomorrow starts with"]))
        XCTAssertFalse(title("Buy a lab notebook", in: app).exists, "not on Today until tomorrow")
        XCTAssertTrue(tap(app.buttons["tab-plan"], shows: title("Buy a lab notebook", in: app)), "it's in Plan")
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
        // The Agent answers from its script (`AgentDemo`): no server, key or subscription. A pretend
        // file is read on launch, as there is no picking one in a test.
        let app = launch(plan: "busy", tab: "agent", more: ["-agentDemo", "YES", "-agentConsent", "YES", "-agentAsk", "Midterm Nov 13"])
        XCTAssertTrue(app.buttons["Choose a file"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.buttons["Choose a photo"].exists)
        XCTAssertFalse(app.textFields.firstMatch.exists, "not a chat: nowhere to type")
        let add = app.buttons["Add 3"]
        XCTAssertTrue(add.waitForExistence(timeout: wait), "the Agent proposes three things")
        let reading = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Read chapter 7'")).firstMatch
        XCTAssertTrue(tap(reading, shows: app.buttons["Add 2"]), "unticking one leaves two")
        XCTAssertTrue(tap(app.buttons["Add 2"], shows: app.staticTexts["Added 2 items"]))
        // Undo takes them out again, and the card offers them again.
        XCTAssertTrue(tap(app.buttons["Undo"], shows: app.buttons["Add 2"]), "Undo brings the button back")
    }

    // MARK: helpers

    /// Starts the app on a known plan.
    private func launch(plan: String, tab: String = "today", more: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-plan", plan, "-tab", tab, "-playSound", "NO", "-focus", "NO"] + more
        app.launch()
        return app
    }

    /// Types a line into Today's "Add a to-do" and taps Add at the top right.
    private func add(_ line: String, in app: XCUIApplication) {
        let field = app.textFields["Add a to-do"]
        XCTAssertTrue(field.waitForExistence(timeout: wait))
        XCTAssertTrue(tap(field, shows: app.keyboards.firstMatch), "the field takes the keyboard")
        field.typeText(line)
        XCTAssertTrue(tap(app.navigationBars.buttons["Add"], shows: title(line, in: app)))
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
