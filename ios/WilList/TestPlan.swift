#if DEBUG
import Foundation
import WilListCore

/// The plans the UI tests start from, by name: `-plan new` (a first launch), `-plan empty` (the
/// welcome seen, nothing added), `-plan a1` (two A's for today). Each lives in a fresh temporary
/// file, so a test never touches a real plan.
enum TestPlan {
    static func store(_ name: String) -> Store {
        let file = URL.temporaryDirectory.appending(path: "willist-uitest.json")
        try? FileManager.default.removeItem(at: file)
        let store = Store(file: file)
        let plan = plan(name, today: store.today)
        store.change { $0 = plan }
        return store
    }

    private static func plan(_ name: String, today: Day) -> AppState {
        var s = AppState()
        guard name != "new" else { return s }
        s.meta.onboarded = true
        if name == "a1" {
            for (rank, title) in ["Write the essay intro", "Read chapter 4"].enumerated() {
                var it = makeItem(Item(id: "", title: title), s.settings, today, s.items)
                it.priority = .A
                it.order = Double(rank)
                s.items.append(it)
            }
        }
        return s
    }
}
#endif
