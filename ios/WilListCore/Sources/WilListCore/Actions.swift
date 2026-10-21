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

    /// Adds a to-do, read the way you'd say it: "Call mum tomorrow 6pm" is due tomorrow at 6.
    @discardableResult
    /// With `readDates` off, the line is kept exactly as typed.
    public mutating func addTodo(_ text: String, today: Day, minute: Int = 0, dateOrder: String = "mdy",
                                 onTop: Bool = false, readDates: Bool = true) -> Todo? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        var todo = Todo(id: newID(), title: t)
        if readDates {
            let p = quickAdd(t, today: today, minute: minute, dateOrder: dateOrder)
            if !p.title.isEmpty { todo.title = p.title }
            todo.date = p.date ?? (p.recur != nil ? today : nil)
            todo.time = todo.date == nil ? nil : p.time
            todo.recur = p.recur
        }
        todo.createdAt = today
        if onTop { todos.insert(todo, at: 0) } else { todos.append(todo) }
        return todo
    }

    /// Ticks a to-do off or back on. Ticking off a repeating one adds the next, due on its next
    /// day (never in the past), with the reminder moved along and the steps unticked; ticking it
    /// back on takes that untouched next one away again.
    public mutating func toggleTodo(_ id: String, today: Day) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[i].done.toggle()
        todos[i].doneAt = todos[i].done ? today : nil
        let t = todos[i]
        guard let recur = t.recur, let due = t.date,
              let next = nextRepeat(recur, from: due, after: diffDays(due, today) > 0 ? addDays(today, -1) : due) else { return }
        if t.done {
            var n = t
            n.id = newID()
            n.done = false
            n.doneAt = nil
            n.date = next
            n.remindAt = shiftReminder(t.remindAt, by: diffDays(due, next))
            n.steps = t.steps.map { Step(id: newID(), title: $0.title) }
            n.createdAt = today
            todos.insert(n, at: i + 1)
        } else if let k = todos.firstIndex(where: { $0.id != t.id && !$0.done && $0.title == t.title && $0.recur == recur
                                                    && $0.date == next && !$0.steps.contains(where: \.done) }) {
            todos.remove(at: k)
        }
    }

    public mutating func removeTodo(_ id: String) { todos.removeAll { $0.id == id } }

    /// Moves a to-do that turned out to matter into the plan as a lettered task, with its steps,
    /// due date, reminder, repeat and note. It stays on Today for the rest of today. Returns the
    /// new item.
    @discardableResult
    public mutating func letterTodo(_ id: String, _ letter: Letter, today: Day) -> Item? {
        guard let t = todos.first(where: { $0.id == id }), !t.done else { return nil }
        var draft = Item(id: "", title: t.title)
        draft.date = t.date
        draft.time = t.time
        draft.recur = t.recur
        draft.priority = letter
        draft.notes = t.notes
        draft.remindAt = t.remindAt
        draft.steps = t.steps
        draft.myDay = today
        let it = makeItem(draft, settings, today, items)
        items.append(it)
        removeTodo(id)
        return it
    }
}

/// A reminder ("YYYY-MM-DDTHH:MM") moved by whole days, at the same time of day.
public func shiftReminder(_ at: String?, by days: Int) -> String? {
    guard let at, let t = at.firstIndex(of: "T") else { return at }
    let d = String(at[..<t])
    guard isValidDay(d) else { return nil }
    return addDays(d, days) + at[t...]
}
