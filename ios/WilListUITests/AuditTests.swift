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
            ("Plan, empty", "empty", ["-tab", "plan"]),
            ("Progress", "busy", ["-tab", "progress"]),
            ("Agent, coming soon", "busy", ["-tab", "agent"]),
            ("Agent, asking first", "busy", ["-tab", "agent", "-agentDemo", "YES", "-agentConsent", "NO"]),
            ("Agent", "busy", ["-tab", "agent", "-agentDemo", "YES", "-agentConsent", "YES"]),
            ("Agent, answered", "busy", ["-tab", "agent", "-agentDemo", "YES", "-agentConsent", "YES", "-agentAsk", "Here's my syllabus"]),
            ("Welcome", "new", []),
            ("Plan tomorrow", "busy", ["-evening", "2"]),
            ("Focus", "busy", ["-focus", "YES"]),
            ("Settings", "busy", ["-open", "settings"]),
            ("Goals", "busy", ["-open", "goals"]),
            ("Search", "busy", ["-tab", "today", "-sheet", "search"]),
            ("Letter sorter", "busy", ["-tab", "today", "-sheet", "letters"]),
            ("To-do details", "busy", ["-tab", "today", "-edit", "t1"]),
            ("Item details", "busy", ["-show", "Read chapter"]),
            ("New task", "busy", ["-tab", "plan", "-sheet", "add"]),
        ]
        for screen in screens {
            let app = XCUIApplication()
            app.launchArguments = ["-plan", screen.plan, "-playSound", "NO", "-night", "NO"]
                + (screen.args.contains("-focus") ? [] : ["-focus", "NO"]) + screen.args
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
            // The Agent's scripted answer takes three rounds of a second each.
            sleep(screen.args.contains("-agentAsk") ? 5 : 1)
            let keyboard = app.keyboards.firstMatch
            try audit(app) { issue in
                // The system keyboard isn't ours (Search opens with it up): the empty slots of the
                // 44-point suggestion bar on top of it have no description, and they come and go
                // while the audit runs, so one may be gone before its frame can be read.
                if let element = issue.element, keyboard.exists,
                   !element.exists || keyboard.frame.insetBy(dx: 0, dy: -44).intersects(element.frame) { return true }
                XCTFail("\(screen.name): \(issue.compactDescription), \(issue.element?.debugDescription ?? "")")
                return true
            }
            // No terminate(): the next launch closes this one. On CI, with the focus Live Activity
            // up, the runner lost track of the app it had just closed, waited a minute and failed
            // (2026-10-23, "Failed to terminate com.lull.willist:0").
        }
    }

    /// On a busy CI machine the audit itself now and then runs out of time before it has looked at
    /// anything (on 2026-10-22: "Audit failed to complete in time"). That says nothing about the
    /// screen, so it runs once more.
    private func audit(_ app: XCUIApplication, _ handle: @escaping (XCUIAccessibilityAuditIssue) throws -> Bool) throws {
        let checks: XCUIAccessibilityAuditType = [.hitRegion, .sufficientElementDescription, .elementDetection, .trait]
        do {
            try app.performAccessibilityAudit(for: checks, handle)
        } catch let error as NSError where error.domain == "com.apple.xcode.xctest.accessibilityAudit" && error.code == -56 {
            try app.performAccessibilityAudit(for: checks, handle)
        }
    }
}
