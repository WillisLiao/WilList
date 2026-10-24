import Testing
@testable import WilListCore

private let tuesday: Day = "2026-10-20"

@Test func a1FirstStreak() {
    #expect(a1Streak(["2026-10-17": "A", "2026-10-18": "B", "2026-10-19": "A", "2026-10-20": "A"], tuesday) == 2)
    #expect(a1Streak(["2026-10-19": "A"], tuesday) == 1, "today not started yet still counts yesterday")
    #expect(a1Streak(["2026-10-20": "C", "2026-10-19": "A"], tuesday) == 0)
}

@Test func firstFinishedItemRecordsItsLetter() {
    var s = AppState()
    s.items = [makeItem(draft("B thing", priority: .B), tuesday),
               makeItem(draft("A thing", priority: .A), tuesday)]
    s.complete(itemId: s.items[0].id, today: tuesday)
    s.complete(itemId: s.items[1].id, today: tuesday)
    #expect(s.meta.firstDone[tuesday] == "B")
    let w = s.weekStats(tuesday)
    #expect(w.done == 2)
    #expect(w.aDone == 1)
}

@Test func deletingProgressStartsTheCountAgain() {
    var s = AppState()
    s.items = [makeItem(draft("Essay", priority: .A), tuesday), makeItem(draft("Lab", priority: .B), tuesday)]
    var todo = Todo(id: "t", title: "Stamps")
    todo.done = true
    todo.doneAt = "2026-10-19"
    s.todos = [todo]
    s.complete(itemId: s.items[0].id, today: tuesday)
    #expect(s.weekStats(tuesday).done == 2)
    s.deleteProgress(today: tuesday)
    #expect(s.weekStats(tuesday).done == 0)
    #expect(s.doneByDay(tuesday, days: 7).allSatisfy { $0.total == 0 })
    #expect(s.meta.firstDone.isEmpty)
    #expect(s.items[0].done && s.todos[0].done, "what was finished stays, to bring back a mistake")
    s.complete(itemId: s.items[1].id, today: tuesday)
    #expect(s.weekStats(tuesday).done == 1, "what's finished after it counts, the same day too")
    #expect(s.doneByDay(tuesday, days: 1)[0].counts[.B] == 1)
}

@Test func doneByDayCountsEachKindOnItsDay() {
    var s = AppState()
    var a = makeItem(draft("Essay", priority: .A), tuesday)
    a.done = true
    a.doneAt = tuesday
    var call = makeItem(draft("Call home", date: "2026-10-18", priority: .B, recur: Recur(.daily)), tuesday)
    call.doneDates = ["2026-10-19", tuesday]
    var todo = Todo(id: "t", title: "Stamps")
    todo.done = true
    todo.doneAt = "2026-10-19"
    s.items = [a, call]
    s.todos = [todo]
    let days = s.doneByDay(tuesday, days: 3)
    #expect(days.map(\.date) == ["2026-10-18", "2026-10-19", tuesday])
    #expect(days.map(\.total) == [0, 2, 2])
    #expect(days[2].counts[.A] == 1 && days[2].counts[.B] == 1)
    #expect(days[1].counts[nil] == 1, "a to-do counts without a letter")
}

@Test func suggestionsComeMostPressingFirst() {
    var s = AppState()
    s.settings = testSettings
    let final = makeItem(draft("Chem final", date: addDays(tuesday, 10), priority: .A), tuesday)
    var old = makeItem(draft("Tidy desk", priority: .D), addDays(tuesday, -20))
    old.createdAt = addDays(tuesday, -20)
    s.items = [final, old, makeItem(draft("Email TA"), tuesday)]
    let found = suggestions(s, tuesday)
    #expect(found.contains(.startEarly(final)))
    #expect(found.contains(.review(ids: [old.id])))
    #expect(found.firstIndex(of: .startEarly(final))! < found.firstIndex(of: .review(ids: [old.id]))!)
}
