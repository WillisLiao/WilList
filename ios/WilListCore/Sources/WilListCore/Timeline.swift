import Foundation

// Turns the lettered list into a day: work goes into the free time between classes and
// meetings, A's first, with short breaks between blocks.

/// Minutes a row still needs today.
public func rowMinutes(_ r: Row, taskMin: Int) -> Int {
    if let s = r.session { return s.minutes * (1 + r.extra) }
    let open = r.item.sessions.filter { !$0.done }
    return open.isEmpty ? taskMin : open.reduce(0) { $0 + $1.minutes }
}

public struct Slot: Equatable, Sendable {
    public enum Kind: Sendable { case event, work }
    public var kind: Kind
    public var start: Int
    public var end: Int
    public var event: Item?
    public var row: Row?
    /// 1, 2, 3… when a block was split over several gaps.
    public var part: Int?
}

public struct DayPlan: Equatable, Sendable {
    public struct Unplaced: Equatable, Sendable {
        public var row: Row
        public var minutes: Int
    }
    public var slots: [Slot]
    public var unplaced: [Unplaced]
    public var freeMin: Int
    public var workMin: Int
}

public func planDay(events: [Item], rows: [Row], dayStart: String = "08:00", dayEnd: String = "22:00", nowMin: Int? = nil,
                    breakMin: Int = 10, taskMin: Int = 25, minBlock: Int = 20) -> DayPlan {
    let start = max(timeToMin(dayStart) ?? 480, nowMin.map { ($0 + 4) / 5 * 5 } ?? 0)
    let end = timeToMin(dayEnd) ?? 1320
    let fixed = events.compactMap { e in
        timeToMin(e.time).map { Slot(kind: .event, start: $0, end: $0 + (e.durationMin ?? 60), event: e) }
    }.sorted { $0.start < $1.start }

    // Free gaps between fixed commitments, with five minutes to get from one place to the next.
    var free: [(s: Int, e: Int)] = []
    var cur = start
    for f in fixed {
        if f.start - 5 > cur { free.append((cur, min(f.start - 5, end))) }
        cur = max(cur, f.end + 5)
    }
    if cur < end { free.append((cur, end)) }
    for k in free.indices where free[k].e - free[k].s < minBlock { free[k].e = free[k].s }

    var slots: [Slot] = []
    var unplaced: [DayPlan.Unplaced] = []
    func take(_ k: Int, _ row: Row, _ minutes: Int, _ part: Int?) {
        slots.append(Slot(kind: .work, start: free[k].s, end: free[k].s + minutes, row: row, part: part))
        free[k].s = min(free[k].e, free[k].s + minutes + breakMin)
    }
    // Anything to hand off or drop gets no time; something without a letter, added to Today, does.
    for row in rows where row.priority.map({ $0 <= .C }) ?? true {
        var rem = rowMinutes(row, taskMin: taskMin)
        if let k = free.firstIndex(where: { $0.e - $0.s >= rem }) {
            take(k, row, rem, nil)
            continue
        }
        // Too big for any one gap: split it over the gaps that are long enough, in time order.
        if rem >= 2 * minBlock {
            var part = 1
            for k in free.indices {
                if rem <= 0 { break }
                let space = free[k].e - free[k].s
                if space < minBlock { continue }
                let n = min(space, rem)
                take(k, row, n, part)
                part += 1
                rem -= n
            }
        }
        if rem > 0 { unplaced.append(.init(row: row, minutes: rem)) }
    }
    let all = (fixed + slots).sorted { ($0.start, $0.kind == .event ? 0 : 1) < ($1.start, $1.kind == .event ? 0 : 1) }
    return DayPlan(slots: all, unplaced: unplaced, freeMin: free.reduce(0) { $0 + max(0, $1.e - $1.s) },
                   workMin: slots.reduce(0) { $0 + $1.end - $1.start })
}

/// One line of Today's column: the day in time order, as on the website.
public struct DayEntry: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        /// The line that marks the time now.
        case now
        /// A class, exam or study block without a time.
        case allDay(Item)
        /// A class, exam or study block at its time.
        case block(Item)
        /// Lettered work fitted into a free stretch.
        case work(Row)
        /// A to-do due at a time today.
        case todo(Todo)
        case free
        case endOfDay
        /// Work that doesn't fit before the end of the day.
        case over(Row)
    }

    public var kind: Kind
    /// Minutes since midnight; nil for all-day blocks and what doesn't fit.
    public var start: Int?
    /// How long it lasts (a free stretch's length too); 0 for the lines and to-dos.
    public var minutes: Int
    /// 1, 2, 3… when work was split over several stretches.
    public var part: Int?
    public var id: String

    init(_ kind: Kind, start: Int?, minutes: Int = 0, part: Int? = nil) {
        self.kind = kind
        self.start = start
        self.minutes = minutes
        self.part = part
        id = switch kind {
        case .now: "now"
        case .allDay(let it), .block(let it): "block-\(it.id)"
        case .work(let r): "work-\(r.key)-\(part ?? 0)"
        case .todo(let t): "todo-\(t.id)"
        case .free: "free-\(start ?? 0)"
        case .endOfDay: "end"
        case .over(let r): "over-\(r.key)"
        }
    }
}

/// Today from now on: to-dos whose time has passed first, the line for now, then blocks, work and
/// timed to-dos in time order with the free stretches between them, the end of the day, and the
/// work that doesn't fit after it. Blocks that have ended are left out.
public func dayColumn(events: [Item], rows: [Row], todos: [Todo], settings: Settings, nowMin: Int, gapMin: Int = 20) -> [DayEntry] {
    let plan = planDay(events: events, rows: rows, dayStart: settings.dayStart, dayEnd: settings.dayEnd, nowMin: nowMin,
                       taskMin: settings.taskMin)
    let start = timeToMin(settings.dayStart) ?? 480, end = timeToMin(settings.dayEnd) ?? 1320
    let timed = todos.compactMap { t in timeToMin(t.time).map { (todo: t, at: $0) } }.sorted { $0.at < $1.at }

    var out = events.filter { $0.time == nil }.map { DayEntry(.allDay($0), start: nil) }
    out += timed.filter { $0.at < nowMin }.map { DayEntry(.todo($0.todo), start: $0.at) }
    out.append(DayEntry(.now, start: nowMin))

    var later = plan.slots.filter { $0.kind == .work || $0.end > nowMin }.map { s in
        s.kind == .event ? DayEntry(.block(s.event!), start: s.start, minutes: s.end - s.start)
            : DayEntry(.work(s.row!), start: s.start, minutes: s.end - s.start, part: s.part)
    }
    later += timed.filter { $0.at >= nowMin }.map { DayEntry(.todo($0.todo), start: $0.at) }
    var cursor = max(start, nowMin)
    for e in later.sorted(by: { $0.start! < $1.start! }) {
        if e.start! - cursor >= gapMin { out.append(DayEntry(.free, start: cursor, minutes: e.start! - cursor)) }
        cursor = max(cursor, e.start! + e.minutes)
        out.append(e)
    }
    if nowMin < end {
        if end - cursor >= gapMin { out.append(DayEntry(.free, start: cursor, minutes: end - cursor)) }
        out.append(DayEntry(.endOfDay, start: end))
    }
    // Work split over the day keeps its placed parts; only work with no time at all is listed here.
    let placed = Set(plan.slots.compactMap { $0.row?.key })
    out += plan.unplaced.filter { !placed.contains($0.row.key) }.map { DayEntry(.over($0.row), start: nil, minutes: $0.minutes) }
    return out
}
