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

/// What got done on one day, by letter; to-dos and unlettered items count under nil.
public struct DayDone: Equatable, Sendable {
    public var date: Day
    public var counts: [Letter?: Int] = [:]
    public var total: Int { counts.values.reduce(0, +) }
}

extension AppState {
    /// What got done on each of the `days` days up to and including `today`, oldest first: whole
    /// items, study sessions, a repeat's times and to-dos, as `weekStats` counts them.
    public func doneByDay(_ today: Day, days: Int) -> [DayDone] {
        var out = (0..<days).map { DayDone(date: addDays(today, $0 - days + 1)) }
        let index = Dictionary(uniqueKeysWithValues: out.indices.map { (out[$0].date, $0) })
        func add(_ d: Day?, _ letter: Letter?) {
            if let d, let i = index[d] { out[i].counts[letter, default: 0] += 1 }
        }
        for it in items {
            if it.done { add(it.doneAt, it.priority) }
            for s in it.sessions where s.done && !(it.done && s.doneAt == it.doneAt) { add(s.doneAt, it.priority) }
            for d in it.doneDates { add(d, it.priority) }
        }
        for t in todos where t.done { add(t.doneAt, nil) }
        return out
    }
}

/// One thing Progress suggests, with what to do about it.
public enum Suggestion: Equatable, Sendable {
    /// Study sessions that were missed: replan them.
    case replan(missed: Int)
    /// A day ahead with more study than the daily time.
    case overloaded(day: Day, minutes: Int, budget: Int)
    /// An A due in four to thirty days with nothing done yet: start it today.
    case startEarly(Item)
    /// C, D and E items over two weeks old: still worth it?
    case review(ids: [String])
    /// Things of a type take longer (or shorter) than planned.
    case calibrate(Calibration)
}

/// What Progress suggests today, most pressing first, each at most once.
public func suggestions(_ s: AppState, _ today: Day) -> [Suggestion] {
    var out: [Suggestion] = []
    let missed = missedSessions(s.items, today).reduce(0) { $0 + $1.count }
    if missed > 0 { out.append(.replan(missed: missed)) }
    if let heavy = radar(s.items, today, days: 7, perDayMin: s.settings.perDayMin).first(where: \.over) {
        out.append(.overloaded(day: heavy.date, minutes: heavy.load, budget: s.settings.perDayMin))
    }
    if let early = importantNotUrgent(s.items, today).first(where: { it in
        !it.sessions.contains(where: \.done) && it.myDay != today
    }) {
        out.append(.startEarly(early))
    }
    let old = s.items.filter { it in
        guard let p = it.priority, p >= .C, isOpen(it, today), let made = it.createdAt else { return false }
        return diffDays(made, today) > 14
    }
    if !old.isEmpty { out.append(.review(ids: old.map(\.id))) }
    if let c = calibrations(s.log, current: s.settings.calib).first { out.append(.calibrate(c)) }
    return out
}
