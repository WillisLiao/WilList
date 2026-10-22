import Foundation
import WilListCore

/// What the widgets show: the day's A1 and what follows it (as on Today and Plan), and the open
/// to-dos (as on Today). Built from the saved plan with the same functions the screens use.
struct Glance: Equatable, Codable {
    struct Line: Equatable, Identifiable, Codable {
        /// The row's key for items (what `FinishRowIntent` ticks), the to-do's id for to-dos.
        var id: String
        var title: String
        var detail: String?
        var label: String?
        var letter: Letter?
        var overdue = false
        /// Just ticked off on a widget: shown done for a moment before it goes (`TickMark`).
        var done = false
        /// Its course's colour (`CourseColor`).
        var color: Int?
    }

    var today: Day
    var first: Line?
    var next: [Line] = []
    var todos: [Line] = []
    var todosDone = 0
    var doneToday = 0

    init(_ s: AppState, today: Day) {
        self.today = today
        let rows = doRows(s.items, today)
        let line = { (r: Row) in
            Line(id: r.key, title: r.item.title, detail: Fmt.detail(r, today), label: r.label, letter: r.priority, overdue: r.overdue,
                 color: s.courseColor(r.item.course))
        }
        first = rows.first.map(line)
        next = rows.dropFirst().map(line)
        // Starred first, as Today shows them by default.
        let open = s.todos.filter { !$0.done }
        todos = (open.filter(\.starred) + open.filter { !$0.starred }).map { t in
            let late = t.date.map { diffDays(today, $0) < 0 } ?? false
            return Line(id: t.id, title: t.title, detail: Fmt.dueLine(t.date, t.time, today), overdue: late)
        }
        todosDone = s.todos.filter { $0.done && $0.doneAt == today }.count
        doneToday = todosDone + doneOn(s.items, today).count
    }

    /// The plan as it is saved right now.
    static func now() -> Glance {
        Glance(PlanFile.read() ?? AppState(), today: WilListCore.today())
    }

    /// The same, with the line with this id shown done.
    func markingDone(_ id: String?) -> Glance {
        var g = self
        if g.first?.id == id { g.first?.done = true }
        for i in g.next.indices where g.next[i].id == id { g.next[i].done = true }
        for i in g.todos.indices where g.todos[i].id == id { g.todos[i].done = true }
        return g
    }

    /// For the widget gallery and the system's previews.
    static let sample: Glance = {
        var g = Glance(AppState(), today: WilListCore.today())
        g.first = Line(id: "a1", title: "Problem set 5", detail: "Start: break it into steps, 50 min", label: "A1", letter: .A)
        g.next = [
            Line(id: "a2", title: "Email TA about quiz regrade", detail: "CHEM110", label: "A2", letter: .A),
            Line(id: "b1", title: "Lab report: titration", detail: "Start: break it into steps, 50 min", label: "B1", letter: .B),
            Line(id: "c1", title: "Renew library books", detail: "Mon", label: "C1", letter: .C),
        ]
        g.todos = [
            Line(id: "t2", title: "Return the lab goggles to Sam", detail: "Due tomorrow, 10:00 AM"),
            Line(id: "t3", title: "Top up transit card", detail: "Overdue, yesterday", overdue: true),
            Line(id: "t1", title: "Pick up laundry"),
            Line(id: "t5", title: "Pack for the field trip", detail: "Due Sat"),
            Line(id: "t6", title: "Water the plants", detail: "Due today"),
        ]
        g.todosDone = 1
        g.doneToday = 2
        return g
    }()
}

/// A tick on a widget, kept for a moment so the widgets can show the line done before it goes:
/// the box fills, then the row leaves (`GlanceProvider`).
struct TickMark: Codable {
    /// What the widgets showed just before the tick, with the ticked line done.
    var glance: Glance
    var at = Date.now

    private static var defaults: UserDefaults { UserDefaults(suiteName: PlanFile.group) ?? .standard }

    /// Called by a tick just before it changes the plan.
    static func note(_ id: String) {
        defaults.set(try? JSONEncoder().encode(TickMark(glance: Glance.now().markingDone(id))), forKey: "ticked")
    }

    /// The last tick, while it is still news (three seconds).
    static var fresh: TickMark? {
        guard let data = defaults.data(forKey: "ticked"), let mark = try? JSONDecoder().decode(TickMark.self, from: data),
              Date.now.timeIntervalSince(mark.at) < 3 else { return nil }
        return mark
    }
}
