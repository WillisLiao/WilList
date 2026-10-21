import ActivityKit
import AppIntents
import Foundation
import WilListCore

/// One focus session on a row of the day, the A1 usually: one thing, one timer, until Done or Stop.
/// It is kept in the app group's defaults, so the app and the Live Activity's Mark done agree on it.
struct FocusSession: Codable, Equatable, Identifiable {
    var key: String
    var itemId: String
    var type: ItemType
    var title: String
    var label: String
    var minutes: Int
    /// Seconds run before the current stretch.
    var banked: TimeInterval = 0
    /// When the current stretch started; nil while paused.
    var since: Date? = .now

    var id: String { key }
    var total: TimeInterval { TimeInterval(minutes) * 60 }
    var paused: Bool { since == nil }

    /// Real time spent, past the planned minutes too: that is what gets logged.
    func elapsed(at now: Date = .now) -> TimeInterval { banked + (since.map { now.timeIntervalSince($0) } ?? 0) }
    func remaining(at now: Date = .now) -> TimeInterval { max(0, total - elapsed(at: now)) }
    /// When the planned minutes run out, while running.
    var end: Date? { since.map { $0.addingTimeInterval(total - banked) } }

    private static var defaults: UserDefaults { UserDefaults(suiteName: PlanFile.group) ?? .standard }

    static var saved: FocusSession? {
        get { defaults.data(forKey: "focus").flatMap { try? JSONDecoder().decode(FocusSession.self, from: $0) } }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: "focus") }
    }
}

/// The Live Activity's facts: what is in focus, and its timer.
struct FocusAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// The planned time spans start...end while running. Paused, end is nil and left holds
        /// the seconds still to go.
        var start: Date
        var end: Date?
        var left: TimeInterval
    }

    var title: String
    var label: String
    var minutes: Int

    var total: TimeInterval { TimeInterval(minutes) * 60 }

    static func state(_ f: FocusSession, at now: Date = .now) -> ContentState {
        ContentState(start: now.addingTimeInterval(-f.elapsed(at: now)), end: f.end, left: f.remaining(at: now))
    }
}

/// Mark done on the Live Activity. It runs in the app, launched in the background if need be,
/// which hands it to its store (`Focus.finish`).
struct FinishFocusIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Mark done"
    static let isDiscoverable = false

    init() {}

    @MainActor func perform() async throws -> some IntentResult {
        Focus.finish?(true)
        return .result()
    }
}

@MainActor enum Focus {
    /// Ends the session, marking its row done when true. Set by the app at launch.
    static var finish: ((Bool) -> Void)?
}
