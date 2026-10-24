import Foundation

// What got done, and what Progress suggests from it.

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
    /// items, a repeat's times and to-dos, as `weekStats` counts them.
    public func doneByDay(_ today: Day, days: Int) -> [DayDone] {
        var out = (0..<days).map { DayDone(date: addDays(today, $0 - days + 1)) }
        let index = Dictionary(uniqueKeysWithValues: out.indices.map { (out[$0].date, $0) })
        func add(_ d: Day?, _ letter: Letter?) {
            if let d, let i = index[d] { out[i].counts[letter, default: 0] += 1 }
        }
        for it in items {
            if it.done { add(it.doneAt, it.priority) }
            for d in it.doneDates { add(d, it.priority) }
        }
        for t in todos where t.done { add(t.doneAt, nil) }
        return out
    }
}

/// One thing Progress suggests, with what to do about it.
public enum Suggestion: Equatable, Sendable {
    /// A day ahead with more study than the daily time.
    case overloaded(day: Day, minutes: Int, budget: Int)
    /// An A due in four to thirty days with nothing done yet: start it today.
    case startEarly(Item)
    /// C, D and E items over two weeks old: still worth it?
    case review(ids: [String])
}

/// What Progress suggests today, most pressing first, each at most once.
public func suggestions(_ s: AppState, _ today: Day) -> [Suggestion] {
    var out: [Suggestion] = []
    if let heavy = radar(s.items, today, days: 7, perDayMin: s.settings.perDayMin).first(where: \.over) {
        out.append(.overloaded(day: heavy.date, minutes: heavy.load, budget: s.settings.perDayMin))
    }
    if let early = importantNotUrgent(s.items, today).first(where: { $0.myDay != today }) {
        out.append(.startEarly(early))
    }
    let old = s.items.filter { it in
        guard let p = it.priority, p >= .C, isOpen(it, today), let made = it.createdAt else { return false }
        return diffDays(made, today) > 14
    }
    if !old.isEmpty { out.append(.review(ids: old.map(\.id))) }
    return out
}
