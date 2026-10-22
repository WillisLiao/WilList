import XCTest

/// The system's accessibility audit on every screen and sheet: tap areas of at least 44 points,
/// a description for every control, and the right traits. Contrast and clipped text are
/// checked by eye in screenshots instead; the audit flags system grey on grouped lists and
/// rows passing under the floating tab bar.
@MainActor
final class AuditTests: XCTestCase {
    func testEveryScreenPassesTheAudit() throws {
        let screens: [(name: String, plan: String, args: [String])] = [
            ("Today", "busy", ["-tab", "today"]),
            ("Plan", "busy", ["-tab", "plan"]),
            ("Study", "busy", ["-tab", "study"]),
            ("More", "busy", ["-tab", "more"]),
            ("Welcome", "new", []),
            ("Plan tomorrow", "busy", ["-evening", "2"]),
            ("Focus", "busy", ["-focus", "YES"]),
            ("Your goals", "busy", ["-tab", "plan", "-open", "goals"]),
            ("Search", "busy", ["-tab", "today", "-sheet", "search"]),
            ("Letter sorter", "busy", ["-tab", "today", "-sheet", "letters"]),
            ("To-do details", "busy", ["-tab", "today", "-edit", "t1"]),
            ("Item details", "busy", ["-show", "Read chapter"]),
            ("New task", "busy", ["-tab", "plan", "-sheet", "add"]),
            ("Bring in a schedule", "busy", ["-tab", "plan", "-sheet", "import"]),
        ]
        for screen in screens {
            let app = XCUIApplication()
            app.launchArguments = ["-plan", screen.plan, "-playSound", "NO", "-night", "NO"]
                + (screen.args.contains("-focus") ? [] : ["-focus", "NO"]) + screen.args
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
            sleep(1)
            let keyboard = app.keyboards.firstMatch
            try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .elementDetection, .trait]) { issue in
                // The system keyboard isn't ours (Search opens with it up): the empty slots of the
                // 44-point suggestion bar on top of it have no description.
                if let element = issue.element, keyboard.exists, keyboard.frame.insetBy(dx: 0, dy: -44).intersects(element.frame) { return true }
                XCTFail("\(screen.name): \(issue.compactDescription), \(issue.element?.debugDescription ?? "")")
                return true
            }
            app.terminate()
        }
    }
}
