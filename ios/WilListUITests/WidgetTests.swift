import XCTest

/// A tick on the Today widget, end to end on the Home Screen: the row shows done for a moment,
/// then leaves. Widgets can only be checked there (the app's widget gallery draws some things a
/// widget drops), so this adds the widget when it isn't there yet. It ticks a real to-do of the
/// plan on the simulator, so it runs only when asked, best after `npm run ios:shots` loads the
/// sample plan: `TEST_RUNNER_WIDGETS=1 xcodebuild test ... -only-testing:WilListUITests/WidgetTests`
@MainActor
final class WidgetTests: XCTestCase {
    private let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    func testTickATodoOnTheTodayWidget() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WIDGETS"] != nil, "Set TEST_RUNNER_WIDGETS=1 to run it.")
        continueAfterFailure = false
        XCUIDevice.shared.press(.home)
        let boxes = home.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Mark ' AND label ENDSWITH ' done' AND label != 'Mark done'"))
        if !boxes.firstMatch.waitForExistence(timeout: 3) { addTodayWidget() }
        XCTAssertTrue(boxes.firstMatch.waitForExistence(timeout: 10), "the Today widget is on the Home Screen")
        let title = String(boxes.firstMatch.label.dropFirst("Mark ".count).dropLast(" done".count))
        boxes.firstMatch.tap()
        let done = home.buttons["\(title), done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3), "the row shows done")
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "then it leaves")
        XCTAssertFalse(home.buttons["Mark \(title) done"].exists)
    }

    /// Edit the Home Screen, Add Widget, find WilList, page to Today (medium) and add it. The
    /// simulator may be in English or in Chinese (Taiwan).
    private func addTodayWidget() {
        home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)).press(forDuration: 2.5)
        tap(named("Edit", "編輯"))
        tap(named("Add Widget", "加入小工具"))
        let search = home.searchFields.firstMatch
        tap(search)
        search.typeText("WilList")
        tap(home.cells.containing(NSPredicate(format: "label CONTAINS 'WilList'")).firstMatch)
        // The sizes page up and down: Do this first small and medium, then Today medium.
        let pages = home.pageIndicators.matching(NSPredicate(format: "value CONTAINS '4'")).firstMatch
        for _ in 0..<2 {
            pages.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            sleep(1)
        }
        tap(home.buttons.matching(NSPredicate(format: "label CONTAINS 'Add Widget' OR label CONTAINS '加入小工具'")).firstMatch)
        tap(named("Done", "完成"))
    }

    private func named(_ labels: String...) -> XCUIElement {
        home.buttons.matching(NSPredicate(format: "label IN %@", labels)).firstMatch
    }

    private func tap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 6), "\(element) on the Home Screen")
        element.tap()
        sleep(1)
    }
}
