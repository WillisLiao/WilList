import XCTest

/// The system's accessibility audit on every main screen: tap areas of at least 44 points,
/// a description for every control, and the right traits. Contrast and clipped text are
/// checked by eye in screenshots instead; the audit flags system grey on grouped lists and
/// rows passing under the floating tab bar.
@MainActor
final class AuditTests: XCTestCase {
    func testEveryScreenPassesTheAudit() throws {
        let screens: [(name: String, plan: String, args: [String])] = [
            ("Today", "a1", ["-tab", "today"]),
            ("Plan", "a1", ["-tab", "plan"]),
            ("Study", "a1", ["-tab", "study"]),
            ("More", "a1", ["-tab", "more"]),
            ("Welcome", "new", []),
            ("Plan tomorrow", "a1", ["-evening", "2"]),
            ("Focus", "a1", ["-focus", "YES"]),
        ]
        for screen in screens {
            let app = XCUIApplication()
            app.launchArguments = ["-plan", screen.plan, "-playSound", "NO", "-night", "NO"]
                + (screen.args.contains("-focus") ? [] : ["-focus", "NO"]) + screen.args
            app.launch()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
            sleep(1)
            try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .elementDetection, .trait]) { issue in
                XCTFail("\(screen.name): \(issue.compactDescription), \(issue.element?.debugDescription ?? "")")
                return true
            }
            app.terminate()
        }
    }
}
