#if DEBUG
import Foundation
import WilListCore

/// The plans the UI tests start from, by name: `-plan new` (a first launch), `-plan empty` (the
/// welcome seen, nothing added), `-plan a1` (two A's for today), `-plan busy` (those, a to-do `t1`
/// and an item waiting for a letter, so every screen and sheet has something on it), `-plan reminder`
/// (a to-do whose reminder comes within 75 seconds; it asks to send notifications, as setting a
/// reminder does). Each lives in a fresh temporary file, so a test never touches a real plan, and
/// starts from the default settings, so nothing an earlier test chose (tomorrow planned, a sort)
/// carries over.
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
        if name == "reminder" {
            // Reminders keep to the minute: this one comes 15 to 75 seconds from now.
            var todo = Todo(id: "t1", title: "Return the lab goggles")
            todo.createdAt = today
            todo.remindAt = Reminders.stamp(.now.addingTimeInterval(75))
            s.todos.append(todo)
        }
        return s
    }
}
#endif
