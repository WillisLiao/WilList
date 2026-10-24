import Foundation

// What you can do to the planner. Each change is a plain function of the state, so the app
// can save, undo and test them the same way.

public func newID() -> String { UUID().uuidString.lowercased() }

/// A new letter lands after every item that already has it: the A added last is the last A,
/// and dragging it up ranks it higher.
func defaultOrder(_ it: Item, after items: [Item]) -> Double {
    (items.filter { $0.priority == it.priority && $0.id != it.id }.map(\.order).max() ?? 0) + 1
}

extension Item {
    /// A draft from typed text, ready for makeItem.
    public init(_ p: Parsed) {
        self.init(id: "", title: p.title)
        course = p.course
        date = p.date
        time = p.time
        durationMin = p.durationMin
        recur = p.recur
        priority = p.priority
    }
}

/// A new item from a draft, ranked after the others with its letter.
public func makeItem(_ draft: Item, _ today: Day, _ items: [Item] = []) -> Item {
    var it = draft
    it.id = newID()
    if it.title.isEmpty { it.title = "Untitled" }
    it.durationMin = it.type == .study ? (draft.durationMin ?? 60) : nil
    it.done = false
    it.doneAt = nil
    it.doneDates = []
    it.createdAt = today
    it.order = defaultOrder(it, after: items)
    return it
}

extension AppState {
    /// How many colours the app has for courses.
    public static let courseColorCount = 8

    /// The key a course is known by: "MATH201" and "math201 " are one course.
    public static func courseKey(_ course: String) -> String { course.trimmingCharacters(in: .whitespaces).lowercased() }

    /// Each course keeps the colour it got when it first appeared. A new course takes the colour
    /// the fewest courses have; a course no item names any more gives its colour back.
    public mutating func colorCourses() {
        let courses = items.compactMap(\.course).map(Self.courseKey).filter { !$0.isEmpty }
        let named = Set(courses)
        var colors = settings.courseColors.filter { named.contains($0.key) && (0..<Self.courseColorCount).contains($0.value) }
        for course in courses where colors[course] == nil {
            let uses = (0..<Self.courseColorCount).map { i in colors.values.count { $0 == i } }
            colors[course] = uses.firstIndex(of: uses.min()!)
        }
        if colors != settings.courseColors { settings.courseColors = colors }
    }

    /// The colour a course is drawn in; nil for no course.
    public func courseColor(_ course: String?) -> Int? {
        course.flatMap { settings.courseColors[Self.courseKey($0)] }
    }

    public func index(of id: String) -> Int? { items.firstIndex { $0.id == id } }

    public mutating func setLetter(_ id: String, _ letter: Letter?) {
        // The same letter again keeps its place: A2 stays A2 rather than being shuffled by date.
        guard let i = index(of: id), items[i].priority != letter else { return }
        items[i].priority = letter
        items[i].order = defaultOrder(items[i], after: items)
    }

    /// Makes an item the A1: an A, ranked ahead of every other A.
    public mutating func makeA1(_ id: String) {
        guard let i = index(of: id) else { return }
        if items[i].priority != .A { setLetter(id, .A) }
        if let first = items.filter({ $0.priority == .A && $0.id != id }).map(\.order).min(), items[i].order >= first {
            items[i].order = first - 1
        }
    }

    /// Ticks off a row: the item, or today's time of a repeating one.
    public mutating func complete(_ row: Row, today: Day) {
        complete(itemId: row.item.id, recurring: row.recurring, today: today)
    }

    public mutating func complete(itemId: String, recurring: Bool = false, today: Day) {
        guard let i = index(of: itemId) else { return }
        meta.doneCount += 1
        noteFirstDone(today, items[i].priority)
        if recurring {
            if !items[i].doneDates.contains(today) { items[i].doneDates.append(today) }
            return
        }
        items[i].done = true
        items[i].doneAt = today
    }

    /// Ticks off an item that isn't on the day's list: the whole item, or a repeat's next time.
    public mutating func completeLater(_ id: String, today: Day) {
        guard let i = index(of: id) else { return }
        guard items[i].recur != nil else { complete(itemId: id, today: today); return }
        let it = items[i]
        guard let next = (0...400).lazy.map({ addDays(today, $0) }).first(where: { occursOn(it, $0) && !it.doneDates.contains($0) }) else { return }
        meta.doneCount += 1
        items[i].doneDates.append(next)
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
        let it = makeItem(draft, today, items)
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
