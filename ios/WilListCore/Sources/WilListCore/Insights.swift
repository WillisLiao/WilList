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
            var hits = it.done && inWeek(it.doneAt) && counts(it.id, on: it.doneAt) ? 1 : 0
            hits += it.doneDates.filter { inWeek($0) && counts(it.id, on: $0) }.count
            w.done += hits
            if it.priority == .A { w.aDone += hits }
        }
        w.done += todos.filter { $0.done && inWeek($0.doneAt) && counts($0.id, on: $0.doneAt) }.count
        return w
    }

    /// Whether something finished on `day` counts in Progress: after Delete progress, nothing
    /// finished up to then does, the things finished earlier that same day included.
    func counts(_ id: String, on day: Day?) -> Bool {
        guard let day else { return false }
        guard let from = meta.countFrom else { return true }
        return day > from || (day == from && !meta.uncounted.contains(id))
    }

    /// Delete progress: Progress and the 21 days in Goals start again from zero. What was
    /// finished stays, so something ticked off by mistake can still be brought back; it just
    /// stops counting.
    public mutating func deleteProgress(today: Day) {
        log = []
        meta.firstDone = [:]
        meta.doneCount = 0
        meta.countFrom = today
        meta.uncounted = items.filter { ($0.done && $0.doneAt == today) || $0.doneDates.contains(today) }.map(\.id)
            + todos.filter { $0.done && $0.doneAt == today }.map(\.id)
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
        func add(_ id: String, _ d: Day?, _ letter: Letter?) {
            if let d, let i = index[d], counts(id, on: d) { out[i].counts[letter, default: 0] += 1 }
        }
        for it in items {
            if it.done { add(it.id, it.doneAt, it.priority) }
            for d in it.doneDates { add(it.id, d, it.priority) }
        }
        for t in todos where t.done { add(t.id, t.doneAt, nil) }
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
