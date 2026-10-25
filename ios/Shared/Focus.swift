import ActivityKit
import Foundation
import WilListCore

/// One focus session on a task, the A1 usually: one thing, one timer, until Stop.
/// It is kept in the app group's defaults, so it outlives the app being closed.
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
struct FocusAttributes {
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
    /// Its course's colour (`CourseColor`), which the Lock Screen face is drawn on.
    var color: Int?

    var total: TimeInterval { TimeInterval(minutes) * 60 }

    static func state(_ f: FocusSession, at now: Date = .now) -> ContentState {
        ContentState(start: now.addingTimeInterval(-f.elapsed(at: now)), end: f.end, left: f.remaining(at: now))
    }
}

// A Mac has no Lock Screen or Dynamic Island, so no Live Activity there.
#if !targetEnvironment(macCatalyst)
extension FocusAttributes: ActivityAttributes {}
#endif
