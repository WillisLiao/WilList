import Foundation
import Testing
@testable import WilListCore

@Test func deletedThingsWaitInTheTrashAndComeBack() {
    var s = AppState()
    s.items = [makeItem(draft("Essay", priority: .A), monday)]
    s.todos = [Todo(id: "t", title: "Stamps")]
    s.trashItem(s.items[0].id, today: monday)
    s.trashTodo("t", today: monday)
    #expect(s.items.isEmpty && s.todos.isEmpty)
    #expect(s.trash.map(\.title) == ["Stamps", "Essay"], "newest first")
    s.restore("t")
    #expect(s.todos.map(\.title) == ["Stamps"], "a to-do goes back to Today")
    #expect(s.trash.map(\.title) == ["Essay"])
}

@Test func theTrashKeepsThingsThirtyDays() {
    var s = AppState()
    s.todos = [Todo(id: "t", title: "Stamps")]
    s.trashTodo("t", today: monday)
    #expect(AppState.daysLeft(monday, monday) == 30)
    #expect(AppState.daysLeft(monday, addDays(monday, 29)) == 1)
    s.purgeTrash(today: addDays(monday, 29))
    #expect(s.trash.count == 1, "still there on its last day")
    s.purgeTrash(today: addDays(monday, 30))
    #expect(s.trash.isEmpty)
}

@Test func theTrashIsSavedAndOlderSavesHaveNone() throws {
    var s = AppState()
    s.todos = [Todo(id: "t", title: "Stamps")]
    s.trashTodo("t", today: monday)
    let back = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(s))
    #expect(back.trash == s.trash)
    let old = try JSONDecoder().decode(AppState.self, from: Data(#"{"v":1,"items":[],"todos":[]}"#.utf8))
    #expect(old.trash.isEmpty)
}
