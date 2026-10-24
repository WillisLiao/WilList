import Foundation

// Turns stored items into what the screens show: the lettered list, what comes later and the
// days ahead.

public func occursOn(_ item: Item, _ iso: Day) -> Bool {
    guard let start = item.date else { return false }
    guard let recur = item.recur else { return start == iso }
    if diffDays(start, iso) < 0 { return false }
    if let until = recur.until, diffDays(iso, until) < 0 { return false }
    if item.skips.contains(iso) { return false }
    return repeats(recur, from: start, on: iso)
}

/// Whether a repeat that began on `start` falls on `iso` (on or after `start`; `until` aside).
public func repeats(_ recur: Recur, from start: Day, on iso: Day) -> Bool {
    let wd = weekday(iso), (a, b) = (dayParts(start), dayParts(iso))
    switch recur.freq {
    case .daily:
        return diffDays(start, iso) % recur.every == 0
    case .weekdays:
        return wd >= 1 && wd <= 5
    case .weekly, .biweekly:
        let days = recur.days ?? []
        return (days.isEmpty ? wd == weekday(start) : days.contains(wd))
            && (diffDays(weekStart(start), weekStart(iso)) / 7) % recur.every == 0
    case .monthly:
        return b.d == a.d && ((b.y - a.y) * 12 + b.m - a.m) % recur.every == 0
    case .yearly:
        return b.m == a.m && b.d == a.d && (b.y - a.y) % recur.every == 0
    }
}

/// The first day the repeat falls on after `day`, within its end date; nil when there is none.
public func nextRepeat(_ recur: Recur, from start: Day, after day: Day) -> Day? {
    var d = addDays(day, 1)
    // Ten years covers every repeat WilList can make, yearly ones included.
    for _ in 0..<3700 {
        if let until = recur.until, diffDays(d, until) < 0 { return nil }
        if repeats(recur, from: start, on: d) { return d }
        d = addDays(d, 1)
    }
    return nil
}

/// A study block is over once its day has passed.
public func isPast(_ item: Item, _ today: Day) -> Bool {
    guard item.type == .study, item.recur == nil, let d = item.date else { return false }
    return diffDays(today, d) < 0
}

public func isOpen(_ item: Item, _ today: Day) -> Bool { !item.done && !isPast(item, today) }

/// Letter first, then the order you ranked them in, then due date.
public func letterKey(_ it: Item) -> (Int, Double, String) { (it.priority?.rank ?? -1, it.order, it.date ?? "9999") }

/// One line of the lettered list.
public struct Row: Identifiable, Equatable, Sendable {
    public var item: Item
    public var overdue = false
    public var recurring = false
    /// "A1", "A2", "B1"… in the order shown.
    public var label = ""
    public var key: String { item.id }
    public var id: String { key }
    public var priority: Letter? { item.priority }

    public init(item: Item, overdue: Bool = false) {
        self.item = item
        self.overdue = overdue
    }
}

/// The actionable list for a day: every open task with a letter, and the repeats that fall on it.
/// Items without a letter are left out: Plan lists them under Later. realToday lets the evening
/// plan look at tomorrow without calling today's things overdue.
public func dayRows(_ items: [Item], _ day: Day, realToday: Day? = nil) -> [Row] {
    let realToday = realToday ?? day
    var rows: [Row] = []
    for it in items where it.type != .study && it.priority != nil {
        if it.recur != nil {
            if occursOn(it, day) && !it.doneDates.contains(day) {
                var r = Row(item: it)
                r.recurring = true
                rows.append(r)
            }
            continue
        }
        if !isOpen(it, realToday) { continue }
        // Due by the day, or not set aside for a later day (the website's "plan for").
        let due = it.date.map { diffDays(day, $0) <= 0 } ?? false
        if due || !(it.plan.map { diffDays(day, $0) > 0 } ?? false) {
            rows.append(Row(item: it, overdue: it.date.map { diffDays(realToday, $0) < 0 } ?? false))
        }
    }
    rows.sort { letterKey($0.item) < letterKey($1.item) }
    var counters: [Letter: Int] = [:]
    for k in rows.indices {
        let p = rows[k].item.priority!
        counters[p, default: 0] += 1
        rows[k].label = "\(p.rawValue)\(counters[p]!)"
    }
    return rows
}

/// The day's rows worth doing yourself, A to C: never something to hand off or drop. The first
/// one is the day's A1, on the card at the top of Today and on the widgets.
public func doRows(_ items: [Item], _ day: Day, realToday: Day? = nil) -> [Row] {
    dayRows(items, day, realToday: realToday).filter { $0.priority.map { $0 <= .C } ?? false }
}

/// Everything that isn't on the day's list: repeats on other days, anything without a letter,
/// study blocks. Plan shows them under the day, soonest first.
public func laterItems(_ items: [Item], _ day: Day) -> [Item] {
    let shown = Set(dayRows(items, day).map(\.item.id))
    func next(_ it: Item) -> Day { it.date ?? "9999" }
    return items
        .filter { isOpen($0, day) && !shown.contains($0.id) }
        .sorted { a, b in next(a) != next(b) ? next(a) < next(b) : letterKey(a) < letterKey(b) }
}

/// Open items still waiting for a letter, soonest first.
public func unsorted(_ items: [Item], _ today: Day) -> [Item] {
    items.filter { $0.type != .study && $0.priority == nil && isOpen($0, today) }
        .sorted { ($0.date ?? "9999") < ($1.date ?? "9999") }
}

/// What was finished on a day: items, and repeats done that day.
public func doneOn(_ items: [Item], _ iso: Day) -> [Item] {
    items.filter { ($0.recur != nil && $0.doneDates.contains(iso)) || ($0.done && $0.doneAt == iso) }
}

/// A day ahead: its study blocks and how much study they come to.
public struct Ahead: Equatable, Sendable {
    public struct Study: Equatable, Sendable {
        public var item: Item
        public var minutes: Int
    }
    public var date: Day
    public var study: [Study]
    public var load: Int
    public var over: Bool
}

/// The next `days` days: the study blocks on each, and whether they come to more than the daily time.
public func radar(_ items: [Item], _ today: Day, days: Int, perDayMin: Int) -> [Ahead] {
    (0..<days).map { k in
        let d = addDays(today, k)
        let study = items.filter { $0.type == .study && occursOn($0, d) && !$0.done && !$0.doneDates.contains(d) }
            .sorted { ($0.time ?? "") < ($1.time ?? "") }
            .map { Ahead.Study(item: $0, minutes: $0.durationMin ?? 60) }
        let load = study.reduce(0) { $0 + $1.minutes }
        return Ahead(date: d, study: study, load: load, over: load > perDayMin)
    }
}

/// "Urgent things are seldom important; important things are seldom urgent."
public func importantNotUrgent(_ items: [Item], _ today: Day) -> [Item] {
    items.filter { it in
        guard it.priority == .A, isOpen(it, today), let d = it.date, it.recur == nil, it.type != .study else { return false }
        return (4...30).contains(diffDays(today, d))
    }
    .sorted { $0.date! < $1.date! }
}
