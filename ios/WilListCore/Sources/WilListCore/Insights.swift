import Foundation

// The learning loop: what you actually did, compared with what you planned.

private let typeWord: [ItemType: String] = [.exam: "Exam prep", .presentation: "Presentation prep", .deadline: "Homework", .reading: "Reading", .task: "Tasks"]

public struct Calibration: Equatable, Sendable {
    public var type: ItemType
    /// Real minutes per planned minute, to one decimal.
    public var ratio: Double
    public var n: Int
    public var label: String
}

/// How long things of a type really take compared with the plan, from finished focus
/// sessions. Says nothing until there are three.
public func calibration(_ log: [FocusLog], _ type: ItemType) -> Calibration? {
    let rows = log.filter { $0.type == type && $0.completed && ($0.planned ?? 0) > 0 }.suffix(20)
    guard rows.count >= 3 else { return nil }
    let real: Int = rows.reduce(0) { $0 + $1.minutes }
    let planned: Int = rows.reduce(0) { $0 + ($1.planned ?? 0) }
    let ratio = Double(real) / Double(planned)
    return Calibration(type: type, ratio: (ratio * 10).rounded() / 10, n: rows.count, label: typeWord[type] ?? type.rawValue)
}

/// Calibrations worth suggesting: ones that differ from what you already accepted.
public func calibrations(_ log: [FocusLog], current: [String: Double] = [:]) -> [Calibration] {
    let types: [ItemType] = [.exam, .presentation, .deadline, .reading]
    return types.compactMap { calibration(log, $0) }.filter { c in
        let accepted = current[c.type.rawValue] ?? 0
        return abs(c.ratio - (accepted != 0 ? accepted : 1)) >= 0.2
    }
}

/// Days in a row where the first thing finished was an A (Tracy: a habit takes about 21 days).
public func a1Streak(_ firstDone: [Day: String], _ today: Day) -> Int {
    var d = firstDone[today] != nil ? today : addDays(today, -1)
    var n = 0
    while firstDone[d] == "A" {
        n += 1
        d = addDays(d, -1)
    }
    return n
}

public struct WeekStats: Equatable, Sendable {
    public var focusMin = 0
    public var done = 0
    public var aDone = 0
    public var aFirstDays = 0
    public var activeDays = 0
}

extension AppState {
    public mutating func logFocus(itemId: String, type: ItemType, title: String, minutes: Double, planned: Int?, completed: Bool, today: Day) {
        guard minutes >= 1 else { return }
        log.append(FocusLog(date: today, itemId: itemId, type: type, title: title, minutes: Int(minutes.rounded()),
                            planned: planned.flatMap { $0 > 0 ? $0 : nil }, completed: completed))
        if log.count > 500 { log.removeFirst(log.count - 500) }
    }

    public mutating func noteFirstDone(_ today: Day, _ letter: Letter?) {
        if meta.firstDone[today] != nil { return }
        meta.firstDone[today] = letter?.rawValue ?? "-"
        meta.firstDone = meta.firstDone.filter { diffDays($0.key, today) <= 60 }
    }

    public func weekStats(_ today: Day) -> WeekStats {
        let from = addDays(today, -6)
        func inWeek(_ d: Day?) -> Bool { d.map { diffDays(from, $0) >= 0 && diffDays($0, today) >= 0 } ?? false }
        var w = WeekStats()
        w.focusMin = log.filter { inWeek($0.date) }.reduce(0) { $0 + $1.minutes }
        for it in items {
            var hits = it.done && inWeek(it.doneAt) ? 1 : 0
            hits += it.sessions.filter { $0.done && inWeek($0.doneAt) && !(it.done && $0.doneAt == it.doneAt) }.count
            hits += it.doneDates.filter(inWeek).count
            w.done += hits
            if it.priority == .A { w.aDone += hits }
        }
        let days = meta.firstDone.filter { inWeek($0.key) }
        w.aFirstDays = days.values.filter { $0 == "A" }.count
        w.activeDays = days.count
        return w
    }
}
