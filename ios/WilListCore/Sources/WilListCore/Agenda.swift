import Foundation

// Turns stored items into what the screens show: the lettered list, the schedule, the
// days ahead and "the vital few".

private let fixedTypes: Set<ItemType> = [.exam, .presentation, .event]

public func occursOn(_ item: Item, _ iso: Day) -> Bool {
    guard let start = item.date else { return false }
    guard let recur = item.recur else { return start == iso }
    if diffDays(start, iso) < 0 { return false }
    if let until = recur.until, diffDays(iso, until) < 0 { return false }
    if item.skips.contains(iso) { return false }
    let wd = weekday(iso)
    switch recur.freq {
    case .daily: return true
    case .weekdays: return wd >= 1 && wd <= 5
    case .weekly: return recur.days?.contains(wd) ?? false
    case .biweekly: return (recur.days?.contains(wd) ?? false) && (diffDays(weekStart(start), weekStart(iso)) / 7) % 2 == 0
    case .monthly: return dayParts(iso).d == dayParts(start).d
    }
}

/// Exams, presentations and one-off events are finished once their day has passed.
public func isPast(_ item: Item, _ today: Day) -> Bool {
    guard fixedTypes.contains(item.type), item.recur == nil, let d = item.date else { return false }
    return diffDays(today, d) < 0
}

public func isOpen(_ item: Item, _ today: Day) -> Bool { !item.done && !isPast(item, today) }

/// Letter first, then the order you ranked them in, then due date.
func letterKey(_ it: Item) -> (Int, Double, String) { (it.priority?.rank ?? -1, it.order, it.date ?? "9999") }

/// Fixed-time commitments for a day: classes, meetings, exams, presentations.
public func scheduleOn(_ items: [Item], _ iso: Day) -> [Item] {
    items.filter { ($0.type == .event && occursOn($0, iso)) || (($0.type == .exam || $0.type == .presentation) && $0.date == iso) }
        .sorted { ($0.time ?? "") < ($1.time ?? "") }
}

/// One line of the lettered list: an item, or the study session of it that is due.
public struct Row: Identifiable, Equatable, Sendable {
    public var key: String
    public var item: Item
    public var session: Session?
    /// More sessions of the same item due today, folded into this row.
    public var extra = 0
    public var overdue = false
    public var recurring = false
    /// "A1", "A2", "B1"… in the order shown.
    public var label = ""
    public var id: String { key }
    public var priority: Letter? { item.priority }

    public init(item: Item, session: Session? = nil, extra: Int = 0, overdue: Bool = false) {
        key = session.map { "\(item.id):\($0.id)" } ?? item.id
        self.item = item
        self.session = session
        self.extra = extra
        self.overdue = overdue
    }
}

/// The actionable list for a day: one row per item, so a task never shows up twice. Items
/// without a letter are left out: they wait to be sorted. realToday lets the evening plan look
/// at tomorrow without calling today's sessions "missed".
public func dayRows(_ items: [Item], _ day: Day, realToday: Day? = nil) -> [Row] {
    let realToday = realToday ?? day
    var rows: [Row] = []
    func row(_ it: Item, _ s: Session? = nil, extra: Int = 0) -> Row {
        let date = s?.date ?? it.date
        return Row(item: it, session: s, extra: extra, overdue: date.map { diffDays(realToday, $0) < 0 } ?? false)
    }
    func sessionRow(_ it: Item, _ open: [Session]) {
        let due = open.filter { diffDays(day, $0.date) <= 0 }
        if let first = due.first { rows.append(row(it, first, extra: due.count - 1)) }
    }
    for it in items where it.type != .event && it.priority != nil {
        if it.recur != nil {
            if occursOn(it, day) && !it.doneDates.contains(day) {
                var r = row(it)
                r.overdue = false
                r.recurring = true
                rows.append(r)
            }
            continue
        }
        if !isOpen(it, realToday) { continue }
        let open = it.sessions.filter { !$0.done }
        if it.type == .exam || it.type == .presentation {
            if let d = it.date, diffDays(day, d) > 0 { sessionRow(it, open) }
            continue
        }
        if let d = it.date, diffDays(day, d) <= 0 { rows.append(row(it)) }
        else if !open.isEmpty { sessionRow(it, open) }
        else if !(it.plan.map { diffDays(day, $0) > 0 } ?? false) { rows.append(row(it)) }
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

/// Study sessions due today or missed, one row per item, soonest deadline first. Unlike the
/// lettered list, items still waiting for a letter are included: the work is real either way.
public func studyRows(_ items: [Item], _ today: Day) -> [Row] {
    items.filter { isOpen($0, today) && $0.priority != .D && $0.priority != .E }
        .compactMap { it in
            let due = it.sessions.filter { !$0.done && diffDays(today, $0.date) <= 0 }
            guard let first = due.first else { return nil }
            return Row(item: it, session: first, extra: due.count - 1, overdue: diffDays(today, first.date) < 0)
        }
        .sorted { ($0.item.date ?? "9999") < ($1.item.date ?? "9999") }
}

/// Open items still waiting for a letter, soonest first.
public func unsorted(_ items: [Item], _ today: Day) -> [Item] {
    items.filter { $0.type != .event && $0.priority == nil && isOpen($0, today) }
        .sorted { ($0.date ?? "9999") < ($1.date ?? "9999") }
}

public struct Finished: Equatable, Sendable {
    public var item: Item
    public var session: Session?
}

public func doneOn(_ items: [Item], _ iso: Day) -> [Finished] {
    var out: [Finished] = []
    for it in items {
        if it.recur != nil && it.doneDates.contains(iso) { out.append(Finished(item: it)) }
        else if it.done && it.doneAt == iso { out.append(Finished(item: it)) }
        for s in it.sessions where s.done && s.doneAt == iso && !it.done { out.append(Finished(item: it, session: s)) }
    }
    return out
}

public struct Ahead: Equatable, Sendable {
    public struct Study: Equatable, Sendable {
        public var item: Item
        public var count: Int
        public var minutes: Int
    }
    public var date: Day
    public var schedule: [Item]
    public var due: [Item]
    public var study: [Study]
    /// Items whose first study session is this day.
    public var starts: [Item]
    public var load: Int
    public var over: Bool
}

/// The next `days` days: what is on, what is due, and how much study each one holds.
public func radar(_ items: [Item], _ today: Day, days: Int, perDayMin: Int) -> [Ahead] {
    (0..<days).map { k in
        let d = addDays(today, k)
        var study: [Ahead.Study] = []
        var starts: [Item] = []
        var load = 0
        for it in items where isOpen(it, today) && !it.sessions.isEmpty {
            let todays = it.sessions.filter { !$0.done && $0.date == d }
            if !todays.isEmpty {
                let minutes = todays.reduce(0) { $0 + $1.minutes }
                load += minutes
                study.append(.init(item: it, count: todays.count, minutes: minutes))
            }
            if !it.sessions.contains(where: \.done), it.sessions.first(where: { !$0.done })?.date == d { starts.append(it) }
        }
        let due = items.filter { !fixedTypes.contains($0.type) && $0.recur == nil && !$0.done && $0.date == d }
        return Ahead(date: d, schedule: scheduleOn(items, d), due: due, study: study, starts: starts, load: load, over: load > perDayMin)
    }
}

public func missedSessions(_ items: [Item], _ today: Day) -> [(item: Item, count: Int)] {
    items.filter { isOpen($0, today) }.compactMap { it in
        let n = it.sessions.filter { !$0.done && diffDays(today, $0.date) < 0 }.count
        return n > 0 ? (it, n) : nil
    }
}

public struct Vital: Equatable, Sendable {
    public enum Status: String, Sendable { case onTrack, short, behind, notStarted, noPlan }
    public var item: Item
    public var done: Int
    public var total: Int
    public var status: Status
    public var startBy: Day?
}

/// The few big things that decide the term, with how far along each one is.
public func vitalFew(_ items: [Item], _ today: Day, horizon: Int = 45) -> [Vital] {
    readiness(items.filter { $0.priority == .A || $0.priority == .B }, today, horizon: horizon)
}

/// Every exam, deadline, presentation and reading in the next `horizon` days that you haven't
/// dropped, soonest first, with how far along each one is.
public func readiness(_ items: [Item], _ today: Day, horizon: Int = 45) -> [Vital] {
    items.filter { it in
        guard plannedTypes.contains(it.type), it.priority != .E, isOpen(it, today), let d = it.date else { return false }
        return (0...horizon).contains(diffDays(today, d))
    }
    .sorted { a, b in a.date != b.date ? a.date! < b.date! : letterKey(a) < letterKey(b) }
    .map { it in
        let s = it.sessions
        let done = s.filter(\.done).count
        let behind = s.contains { !$0.done && diffDays(today, $0.date) < 0 }
        let firstOpen = s.first { !$0.done }
        let status: Vital.Status =
            if it.shortfallMin > 0 { .short }
            else if behind { .behind }
            else if done == 0, let f = firstOpen, diffDays(today, f.date) > 0 { .notStarted }
            else if s.isEmpty { .noPlan }
            else { .onTrack }
        return Vital(item: it, done: done, total: s.count, status: status, startBy: firstOpen?.date ?? it.startBy)
    }
}

/// "Urgent things are seldom important; important things are seldom urgent."
public func importantNotUrgent(_ items: [Item], _ today: Day) -> [Item] {
    items.filter { it in
        guard it.priority == .A, isOpen(it, today), let d = it.date, it.recur == nil, it.type != .event else { return false }
        return (4...30).contains(diffDays(today, d))
    }
    .sorted { $0.date! < $1.date! }
}
