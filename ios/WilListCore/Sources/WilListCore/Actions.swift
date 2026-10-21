import Foundation

// What you can do to the planner. Each change is a plain function of the state, so the app
// can save, undo and test them the same way.

/// The suggested letter when sorting. A share of the grade is the clearest consequence a
/// student has; without one, fall back on what kind of thing it is.
public func suggestedLetter(_ type: ItemType, weightPct: Double? = nil) -> Letter? {
    if let w = weightPct, w > 0 { return w >= 10 ? .A : w >= 3 ? .B : .C }
    switch type {
    case .exam, .presentation, .deadline: return .A
    case .reading: return .B
    default: return nil
    }
}

/// New letters land in due-date order; you can re-rank afterwards.
func defaultOrder(_ it: Item) -> Double {
    if let d = it.date { return Double(diffDays("2000-01-01", d) * 1000 + Int.random(in: 0..<900)) }
    return 9e9 + Double(Int(Date().timeIntervalSince1970 * 1000) % 1_000_000)
}

private func calibrated(_ type: ItemType, _ title: String, _ settings: Settings) -> Int {
    let ratio = settings.calib[type.rawValue].flatMap { $0 > 0 ? $0 : nil } ?? 1
    return Int((Double(suggestEffort(type, title)) * ratio / 5).rounded()) * 5
}

extension Item {
    /// A draft from typed text, ready for makeItem.
    public init(_ p: Parsed) {
        self.init(id: "", title: p.title, type: p.type)
        course = p.course
        date = p.date
        time = p.time
        durationMin = p.durationMin
        recur = p.recur
        weightPct = p.weightPct
        priority = p.priority
    }
}

/// A new item from a draft: effort estimated, ranked in due-date order and planned around
/// everything else already booked.
public func makeItem(_ draft: Item, _ settings: Settings, _ today: Day, _ items: [Item] = []) -> Item {
    var it = draft
    it.id = newID()
    if it.title.isEmpty { it.title = "Untitled" }
    it.durationMin = it.type == .event ? (draft.durationMin ?? 60) : nil
    // For planned work a typed duration ("essay due fri 4h") means effort.
    it.effortMin = plannedTypes.contains(it.type)
        ? [draft.effortMin, draft.durationMin ?? 0].first { $0 > 0 } ?? calibrated(it.type, it.title, settings)
        : 0
    it.sessions = []
    it.startBy = nil
    it.shortfallMin = 0
    it.done = false
    it.doneAt = nil
    it.doneDates = []
    it.createdAt = today
    it.order = defaultOrder(it)
    applyPlan(&it, settings, today, items)
    return it
}

/// Plans the work that is left around everything else already booked. Repeating, delegated
/// and eliminated items get no study time of their own.
public func applyPlan(_ it: inout Item, _ settings: Settings, _ today: Day, _ items: [Item] = []) {
    if !plannedTypes.contains(it.type) || it.recur != nil || it.priority == .D || it.priority == .E {
        it.sessions = plannedTypes.contains(it.type) ? it.sessions.filter(\.done) : []
        it.startBy = it.date
        it.shortfallMin = 0
        return
    }
    let r = buildPlan(it, settings, today, load: studyLoad(items, excluding: it.id))
    it.sessions = r.sessions
    it.startBy = r.startBy
    it.shortfallMin = r.shortfallMin
}

extension AppState {
    public func index(of id: String) -> Int? { items.firstIndex { $0.id == id } }

    public mutating func setLetter(_ id: String, _ letter: Letter?, today: Day? = nil) {
        guard let i = index(of: id) else { return }
        let wasIdle = items[i].priority == .D || items[i].priority == .E
        items[i].priority = letter
        items[i].order = defaultOrder(items[i])
        if let today, letter == .D || letter == .E || wasIdle { replan(id, today: today) }
    }

    /// Ticks off a row. True when that finished the whole item.
    @discardableResult
    public mutating func complete(_ row: Row, today: Day) -> Bool {
        complete(itemId: row.item.id, sessionId: row.session?.id, recurring: row.recurring, today: today)
    }

    @discardableResult
    public mutating func complete(itemId: String, sessionId: String? = nil, recurring: Bool = false, today: Day) -> Bool {
        guard let i = index(of: itemId) else { return false }
        meta.doneCount += 1
        noteFirstDone(today, items[i].priority)
        if recurring {
            if !items[i].doneDates.contains(today) { items[i].doneDates.append(today) }
            return false
        }
        if let sessionId {
            if let k = items[i].sessions.firstIndex(where: { $0.id == sessionId }) {
                items[i].sessions[k].done = true
                items[i].sessions[k].doneAt = today
            }
            let finished = !items[i].sessions.contains { !$0.done } && (items[i].type == .deadline || items[i].type == .reading)
            if finished {
                items[i].done = true
                items[i].doneAt = today
            }
            return finished
        }
        items[i].done = true
        items[i].doneAt = today
        for k in items[i].sessions.indices where !items[i].sessions[k].done {
            items[i].sessions[k].done = true
            items[i].sessions[k].doneAt = today
        }
        return true
    }

    /// Swaps rank with the neighbouring item in the same letter.
    public mutating func move(_ rows: [Row], key: String, by dir: Int) {
        guard let idx = rows.firstIndex(where: { $0.key == key }) else { return }
        let me = rows[idx]
        var j = idx + dir
        while rows.indices.contains(j), rows[j].item.id == me.item.id { j += dir }
        guard rows.indices.contains(j), rows[j].priority == me.priority,
              let a = index(of: me.item.id), let b = index(of: rows[j].item.id) else { return }
        if items[a].order == items[b].order { items[b].order += Double(dir) }
        (items[a].order, items[b].order) = (items[b].order, items[a].order)
    }

    /// Keeps finished sessions; everything left, missed or not, is spread again from today.
    public mutating func replan(_ id: String, today: Day) {
        guard let i = index(of: id) else { return }
        items[i].sessions = items[i].sessions.filter(\.done)
        var it = items[i]
        applyPlan(&it, settings, today, items)
        items[i] = it
    }

    /// Spreads all upcoming work again. A's get first claim on each day's study time, then
    /// B's, then the rest; within a letter, the earliest deadline goes first.
    @discardableResult
    public mutating func replanAll(today: Day) -> Int {
        let open = items.indices.filter { i in
            let it = items[i]
            guard !it.done, plannedTypes.contains(it.type), it.recur == nil, let d = it.date else { return false }
            return diffDays(today, d) >= 0
        }
        for i in open { items[i].sessions = items[i].sessions.filter(\.done) }
        func claim(_ p: Letter?) -> Int { p.map { min($0.rank, 3) } ?? 3 }
        for i in open.sorted(by: { (claim(items[$0].priority), items[$0].date!) < (claim(items[$1].priority), items[$1].date!) }) {
            var it = items[i]
            applyPlan(&it, settings, today, items)
            items[i] = it
        }
        return open.count
    }

    // Plain to-dos on Today.

    public mutating func addTodo(_ title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { todos.append(Todo(id: newID(), title: t)) }
    }

    public mutating func toggleTodo(_ id: String, today: Day) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[i].done.toggle()
        todos[i].doneAt = todos[i].done ? today : nil
    }

    public mutating func removeTodo(_ id: String) { todos.removeAll { $0.id == id } }
}
