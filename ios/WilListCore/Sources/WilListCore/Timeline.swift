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
    for row in rows where [.A, .B, .C].contains(row.priority) {
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
