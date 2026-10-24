import Foundation

// Backward planning: turn "exam on the 30th, ~8h of prep" into dated sessions and a start
// date, so important-but-not-urgent work shows up before it is urgent.

public let plannedTypes: Set<ItemType> = [.exam, .presentation, .deadline, .reading]

public func newID() -> String { UUID().uuidString.lowercased() }

public func suggestEffort(_ type: ItemType, _ title: String = "") -> Int {
    let t = title.lowercased()
    func has(_ p: String) -> Bool { matches(t, p) }
    switch type {
    case .exam:
        if has(#"\bquiz"#) { return 120 }
        if has(#"\bfinals?\b"#) { return 900 }
        if has(#"\bmidterms?\b"#) { return 480 }
        return 360
    case .presentation:
        return has(#"\b(defen[cs]e|thesis|final)\b"#) ? 480 : 240
    case .deadline:
        if has(#"\b(thesis|dissertation)\b"#) { return 1200 }
        if has(#"\b(project|report|essay|paper|portfolio)\b"#) { return 600 }
        if has(#"\b(application|apply)\b"#) { return 240 }
        return 180
    case .reading:
        if has(#"\bpapers?\b"#) { return 120 }
        if has(#"\b(chapters|book|textbook)\b"#) { return 240 }
        return 120
    case .task, .event, .study:
        return 0
    }
}

// Exams get expanding gaps (spaced repetition) counted back from the day before.
private let examOffsets = [0, 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 66, 78, 91]
// Everything else: every other day back from the last working day.
private let steadyOffsets = (0..<40).map { $0 * 2 }

// Last day work should happen on, or nil if it is too late for a plan.
private func lastWorkDay(_ type: ItemType, _ due: Day, _ today: Day, _ bufferDays: Int) -> Day? {
    let gap = diffDays(today, due)
    if gap < 0 { return nil }
    if type == .exam || type == .presentation { return gap >= 1 ? addDays(due, -1) : nil }
    // Deadlines: finish a buffer day early when there is room.
    return addDays(due, -min(bufferDays, gap))
}

// Picks days for n sessions. cap(d) limits sessions per day; counts and order carry over
// between passes so a second, looser pass can top up the first.
private func pickDays(window: [Day], n: Int, maxPerDay: Int, offsets: [Int], protectLast: Bool,
                      cap: (Day) -> Int, counts: inout [Day: Int], order: inout [Day]) {
    func add(_ d: Day) {
        counts[d, default: 0] += 1
        order.append(d)
    }
    for off in offsets where off < window.count {
        if order.count >= n { break }
        let d = window[off]
        if counts[d] == 0 && cap(d) > 0 { add(d) }
    }
    for d in window {
        if order.count >= n { break }
        if counts[d] == 0 && cap(d) > 0 { add(d) }
    }
    // Doubles go nearest the deadline first, keeping the final day light.
    let doubleOrder = protectLast && window.count > 1 ? Array(window.dropFirst()) + [window[0]] : window
    var round = 1
    while order.count < n && round < maxPerDay {
        for d in doubleOrder {
            if order.count >= n { break }
            if counts[d] == round && round < cap(d) { add(d) }
        }
        round += 1
    }
}

/// Minutes of open study already planned per day, by every other item.
public func studyLoad(_ items: [Item], excluding id: String? = nil) -> [Day: Int] {
    var load: [Day: Int] = [:]
    for it in items where it.id != id && !it.done && it.priority != .D && it.priority != .E {
        for s in it.sessions where !s.done { load[s.date, default: 0] += s.minutes }
    }
    return load
}

private func labelFor(_ type: ItemType, _ k: Int, _ n: Int) -> String {
    let first = k == 0, last = k == n - 1
    switch type {
    case .exam:
        if n == 1 { return "Review + practice questions" }
        if first { return "First pass: list every topic, mark the gaps" }
        if last { return "Light review, then sleep early" }
        return "Recall practice \(k + 1)/\(n): test yourself, no notes"
    case .presentation:
        if n == 1 { return "Prepare + rehearse out loud" }
        if first { return "Write your one key message + outline" }
        if last { return "Final run-through out loud, timed" }
        if k == 1 { return "Build slides / script" }
        return "Rehearse out loud \(k - 1)"
    case .reading:
        if n == 1 { return "Read + write 3 takeaways" }
        if last { return "Finish + write 3 takeaways" }
        return "Read part \(k + 1)/\(n)"
    default:
        if n == 1 { return "Do it + submit" }
        if first { return "Start: break it into steps" }
        if last { return "Finish + submit early" }
        return "Work session \(k + 1)/\(n)"
    }
}

public struct PlanResult: Equatable, Sendable {
    public var sessions: [Session]
    public var startBy: Day?
    public var shortfallMin: Int
}

/// Sessions for the effort that is still left. Sessions already done are kept.
public func buildPlan(_ item: Item, _ settings: Settings, _ today: Day, load: [Day: Int] = [:]) -> PlanResult {
    let sessionMin = max(15, settings.sessionMin > 0 ? settings.sessionMin : 50)
    let perDayMin = max(sessionMin, settings.perDayMin > 0 ? settings.perDayMin : 120)
    let kept = item.sessions.filter(\.done)
    let remaining = max(0, item.effortMin - kept.reduce(0) { $0 + $1.minutes })
    var result = PlanResult(sessions: kept, startBy: item.date, shortfallMin: 0)
    guard plannedTypes.contains(item.type), let due = item.date, remaining > 0 else {
        result.startBy = kept.first?.date ?? item.date
        return result
    }
    guard let last = lastWorkDay(item.type, due, today, settings.bufferDays), diffDays(today, last) >= 0 else {
        result.shortfallMin = remaining
        result.startBy = today
        return result
    }
    var window: [Day] = []
    var d = last
    while diffDays(today, d) >= 0 {
        window.append(d)
        d = addDays(d, -1)
    }
    // Split the effort into roughly session-sized blocks without inflating it.
    let n = max(1, Int((Double(remaining) / Double(sessionMin)).rounded()))
    let each = Int((Double(remaining) / Double(n) / 5).rounded(.up)) * 5
    let maxPerDay = max(1, perDayMin / each)
    var counts = Dictionary(uniqueKeysWithValues: window.map { ($0, 0) })
    var order: [Day] = []
    // First fit around what other items already booked.
    let free = { (d: Day) in min(maxPerDay, Int((Double(perDayMin - (load[d] ?? 0)) / Double(each)).rounded(.down))) }
    pickDays(window: window, n: n, maxPerDay: maxPerDay, offsets: item.type == .exam ? examOffsets : steadyOffsets,
             protectLast: item.type == .exam || item.type == .presentation, cap: free, counts: &counts, order: &order)
    // If it does not fit, overbook where it hurts least: the day with the least study on it.
    while order.count < n {
        var best: Day?
        var bestTotal = Int.max
        for d in window where counts[d]! < maxPerDay {
            let total = (load[d] ?? 0) + counts[d]! * each
            if total < bestTotal { best = d; bestTotal = total }
        }
        guard let best else { break }
        counts[best]! += 1
        order.append(best)
    }
    if order.count < n { result.shortfallMin = max(0, remaining - order.count * each) }
    let days = order.sorted()
    let fresh = days.enumerated().map { k, date in
        Session(id: newID(), date: date, minutes: each, label: labelFor(item.type, k + kept.count, days.count + kept.count))
    }
    result.sessions = (kept + fresh).sorted { $0.date < $1.date }
    result.startBy = result.sessions.first?.date ?? today
    return result
}
