#if DEBUG
import Foundation
import WilListCore

/// The plans the UI tests and screenshots start from, by name: `-plan new` (a first launch),
/// `-plan empty` (the welcome seen, nothing added), `-plan a1` (two A's for today), `-plan busy`
/// (those, a to-do `t1` and an item without a letter, so every screen and sheet has something on
/// it), `-plan reminder` (a to-do whose reminder comes within 75 seconds; it asks to send
/// notifications, as setting a reminder does), `-plan sample` (a full student week, for
/// `npm run ios:shots`). Each lives in a fresh temporary file, so a test never touches a real plan,
/// and starts from the default settings, so nothing an earlier test chose (tomorrow planned, a
/// sort) carries over.
enum TestPlan {
    static func store(_ name: String) -> Store {
        if let app = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: app) }
        let file = URL.temporaryDirectory.appending(path: "willist-uitest.json")
        try? FileManager.default.removeItem(at: file)
        let store = Store(file: file)
        let plan = plan(name, today: store.today)
        store.change { $0 = plan }
        if name == "reminder" {
            Task { if await Reminders.allowed() { await Reminders.sync(Reminders.due(store.state, today: store.today)) } }
        }
        return store
    }

    private static func plan(_ name: String, today: Day) -> AppState {
        var s = AppState()
        guard name != "new" else { return s }
        s.meta.onboarded = true
        if name == "a1" || name == "busy" {
            for (rank, title) in ["Write the essay intro", "Read chapter 4"].enumerated() {
                var it = makeItem(Item(id: "", title: title), s.settings, today, s.items)
                it.priority = .A
                it.order = Double(rank)
                s.items.append(it)
            }
        }
        if name == "busy" {
            var todo = Todo(id: "t1", title: "Buy stamps")
            todo.createdAt = today
            s.todos.append(todo)
            s.items.append(makeItem(Item(id: "", title: "Apply for the summer program"), s.settings, today, s.items))
        }
        if name == "sample" { sample(&s, today: today) }
        if name == "reminder" {
            // Reminders keep to the minute: this one comes 15 to 75 seconds from now.
            var todo = Todo(id: "t1", title: "Return the lab goggles")
            todo.createdAt = today
            todo.remindAt = Reminders.stamp(.now.addingTimeInterval(75))
            s.todos.append(todo)
        }
        return s
    }

    /// The screenshots' plan (`npm run ios:shots`): a believable student week dated from today,
    /// with to-dos and items that use every task detail.
    private static func sample(_ s: inout AppState, today: Day) {
        let d = { (n: Int) in addDays(today, n) }
        func goal(_ title: String, _ area: Goal.Area, days: Int, why: String, rock: String) -> Goal {
            var g = Goal(id: newID(), title: title, area: area)
            g.deadline = d(days)
            g.why = why
            g.rock = rock
            g.createdAt = today
            return g
        }
        var gpa = goal("I earn an A in Calculus", .academic, days: 55, why: "It keeps my scholarship.\nI want the engineering track.",
                       rock: "I fall behind on problem sets and cram.")
        gpa.knowledge = "Related rates and optimization"
        gpa.people = "Prof. Lee, TA office hours, study group"
        gpa.reward = "Weekend trip"
        let family = goal("I call my family every Sunday", .personal, days: 60, why: "They are the reason I’m here.", rock: "Sunday evenings fill up with homework.")
        let sleep = goal("I’m in bed by 11:30 on school nights", .`self`, days: 30, why: "I think and remember better when I sleep.", rock: "Phone in bed.")
        s.goals = [gpa, family, sleep]
        s.mdp = "I finish this semester with a 3.7 GPA"

        let wd = weekday(today)
        func add(_ title: String, _ type: ItemType, _ letter: Letter? = nil, course: String? = nil, on day: Int? = nil, at time: String? = nil,
                 for minutes: Int? = nil, weekly days: [Int]? = nil, effort: Int = 0, weight: Double? = nil, goal: String? = nil) {
            var it = Item(id: "", title: title, type: type)
            it.course = course
            it.date = day.map(d)
            it.time = time
            it.durationMin = minutes
            it.recur = days.map { Recur(.weekly, days: $0) }
            it.priority = letter
            it.effortMin = effort
            it.weightPct = weight
            it.goalId = goal
            // Each planned on its own, so the week ahead has a heavy day to show.
            s.items.append(makeItem(it, s.settings, today))
        }
        add("Calculus lecture", .event, course: "MATH201", on: 0, at: "10:00", for: 50, weekly: [1, 3, 5])
        add("Chemistry lab", .event, course: "CHEM110", on: 0, at: "14:00", for: 180, weekly: [wd == 0 || wd == 6 ? 3 : wd])
        add("Research group meeting", .event, on: 0, at: "16:30", for: 60, weekly: [2])
        add("Office hours with Prof. Lee", .event, course: "MATH201", on: 3, at: "15:00", for: 30)
        add("Calculus midterm", .exam, .A, course: "MATH201", on: 12, at: "09:00", effort: 360, weight: 25, goal: gpa.id)
        add("Chem quiz 4", .exam, .A, course: "CHEM110", on: 3, effort: 120, weight: 5)
        add("History presentation: the printing press", .presentation, .A, course: "HIST150", on: 9, at: "13:00", effort: 180, weight: 15)
        add("Problem set 5", .deadline, .A, course: "MATH201", on: 2, at: "23:59", effort: 100, goal: gpa.id)
        add("Lab report: titration", .deadline, .B, course: "CHEM110", on: 6, effort: 150, weight: 8)
        add("Read 2 papers for research group", .reading, .B, on: 7, effort: 120)
        add("Email TA about quiz regrade", .task, .A, course: "CHEM110")
        add("Call home", .task, .B, on: (7 - wd) % 7, weekly: [0], goal: family.id)
        add("Renew library books", .task, .C, on: 4)
        add("Poster template for group project", .task, .D)
        add("Reorganize desktop folders", .task, .E)
        add("Apply for summer research program", .deadline, on: 24, effort: 120)
        add("Buy printer ink", .task)
        func edit(_ title: String, _ change: (inout Item) -> Void) {
            if let i = s.items.firstIndex(where: { $0.title == title }) { change(&s.items[i]) }
        }
        edit("Poster template for group project") { $0.delegateTo = "Sam (teammate)" }
        edit("Email TA about quiz regrade") {
            $0.myDay = today
            $0.remindAt = "\(today)T16:00"
            $0.steps = [Step(id: "x1", title: "Find the quiz", done: true), Step(id: "x2", title: "Write two lines")]
        }
        // A few study sessions already behind you, so Progress has something to show.
        for (title, days) in [("Calculus midterm", [-5, -3, -1]), ("History presentation: the printing press", [-2])] {
            edit(title) { it in
                for n in days { it.sessions.insert(Session(id: newID(), date: d(n), minutes: 50, label: "Study", done: true, doneAt: d(n)), at: 0) }
            }
        }
        // What was finished first on recent days.
        s.meta.firstDone = [d(-1): "A", d(-2): "A", d(-3): "A", d(-4): "B", d(-5): "A", d(-7): "A"]

        // To-dos with every task detail; `-edit t5` opens one.
        func todo(_ id: String, _ title: String, made: Int, _ change: (inout Todo) -> Void = { _ in }) -> Todo {
            var t = Todo(id: id, title: title)
            t.createdAt = d(made)
            change(&t)
            return t
        }
        s.todos = [
            todo("t1", "Pick up laundry", made: -1),
            todo("t2", "Return the lab goggles to Sam", made: -2) { t in
                t.date = d(1)
                t.time = "10:00"
                t.remindAt = "\(d(1))T09:00"
                t.starred = true
            },
            todo("t3", "Top up transit card", made: -3) { $0.date = d(-1) },
            todo("t5", "Pack for the field trip", made: 0) { t in
                t.date = d(2)
                t.notes = "Bus leaves from the north gate."
                t.steps = [Step(id: "s1", title: "Rain jacket", done: true), Step(id: "s2", title: "Notebook"), Step(id: "s3", title: "Water bottle")]
            },
            todo("t6", "Water the plants", made: -7) { t in
                t.date = today
                t.recur = Recur(.weekly, days: [])
            },
            todo("t4", "Reply to Mia about Saturday", made: -1) { t in
                t.done = true
                t.doneAt = today
            },
        ]
    }
}
#endif
