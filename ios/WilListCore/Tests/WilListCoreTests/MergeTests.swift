import Foundation
import Testing
@testable import WilListCore

// Two devices change one plan apart; iCloud brings the copies back together (PlanMerge).

private func todo(_ id: String, _ title: String, done: Bool = false) -> Todo {
    var t = Todo(id: id, title: title)
    t.done = done
    return t
}

private func plan(_ todos: [Todo], mdp: String = "") -> AppState {
    var s = AppState()
    s.todos = todos
    s.mdp = mdp
    return s
}

private func merged(base: AppState?, local: AppState, remote: AppState) throws -> AppState {
    let enc = JSONEncoder()
    let data = try PlanMerge.merge(base: try base.map { try enc.encode($0) }, local: try enc.encode(local), remote: try enc.encode(remote))
    return try JSONDecoder().decode(AppState.self, from: data)
}

@Test func editsToDifferentThingsBothStay() throws {
    let base = plan([todo("a", "Buy stamps"), todo("b", "Call mum")])
    var phone = base, tablet = base
    phone.todos[0].done = true
    tablet.todos[1].title = "Call mum tonight"
    tablet.mdp = "A 3.7 GPA"
    let m = try merged(base: base, local: phone, remote: tablet)
    #expect(m.todos.map(\.title) == ["Buy stamps", "Call mum tonight"])
    #expect(m.todos[0].done, "the phone's tick")
    #expect(m.mdp == "A 3.7 GPA", "the tablet's goal")
}

@Test func editsToDifferentFieldsOfOneThingBothStay() throws {
    let base = plan([todo("a", "Buy stamps")])
    var phone = base, tablet = base
    phone.todos[0].done = true
    tablet.todos[0].title = "Buy stamps and envelopes"
    let m = try merged(base: base, local: phone, remote: tablet)
    #expect(m.todos == [todo("a", "Buy stamps and envelopes", done: true)])
}

@Test func whatEitherSideAddedComesIn() throws {
    let base = plan([todo("a", "Buy stamps")])
    var phone = base, tablet = base
    phone.todos.append(todo("p", "From the phone"))
    tablet.todos.insert(todo("t", "From the tablet"), at: 0)
    let m = try merged(base: base, local: phone, remote: tablet)
    #expect(m.todos.map(\.id) == ["t", "a", "p"], "each where its side put it")
}

@Test func aDeleteGoesUnlessTheOtherSideChangedIt() throws {
    let base = plan([todo("a", "Buy stamps"), todo("b", "Call mum")])
    var phone = base, tablet = base
    phone.todos.removeAll() // both deleted on the phone
    tablet.todos[1].done = true // and one ticked meanwhile on the tablet
    let m = try merged(base: base, local: phone, remote: tablet)
    #expect(m.todos.map(\.id) == ["b"], "the untouched one goes; the one changed elsewhere stays")
}

@Test func aClearedValueStaysCleared() throws {
    var base = plan([todo("a", "Buy stamps")])
    base.todos[0].remindAt = "2026-10-24T09:00"
    var phone = base
    let tablet = base
    phone.todos[0].remindAt = nil
    let m = try merged(base: base, local: phone, remote: tablet)
    #expect(m.todos[0].remindAt == nil)
}

@Test func theSameFieldChangedOnBothKeepsThisDevicesChange() throws {
    let base = plan([todo("a", "Buy stamps")])
    var phone = base, tablet = base
    phone.todos[0].title = "Phone's title"
    tablet.todos[0].title = "Tablet's title"
    #expect(try merged(base: base, local: phone, remote: tablet).todos[0].title == "Phone's title")
}

@Test func listsWithoutIdsKeepEveryAddition() throws {
    var base = plan([])
    var item = Item(id: "i", title: "Run")
    item.doneDates = ["2026-10-20"]
    base.items = [item]
    var phone = base, tablet = base
    phone.items[0].doneDates.append("2026-10-21")
    tablet.items[0].doneDates.append("2026-10-22")
    tablet.items[0].doneDates.removeFirst()
    phone.log.append(FocusLog(date: "2026-10-21", itemId: "i", type: .task, title: "Run", minutes: 25, planned: 25, completed: true))
    tablet.log.append(FocusLog(date: "2026-10-22", itemId: "i", type: .task, title: "Run", minutes: 30, planned: 25, completed: false))
    let m = try merged(base: base, local: phone, remote: tablet)
    #expect(m.items[0].doneDates == ["2026-10-21", "2026-10-22"], "one removed on the tablet, one added on each")
    #expect(m.log.map(\.minutes) == [25, 30])
}

@Test func aReorderOnOneSideIsKept() throws {
    let base = plan([todo("a", "A"), todo("b", "B"), todo("c", "C")])
    var phone = base, tablet = base
    tablet.todos = [base.todos[2], base.todos[0], base.todos[1]]
    phone.todos[0].done = true
    let m = try merged(base: base, local: phone, remote: tablet)
    #expect(m.todos.map(\.id) == ["c", "a", "b"])
    #expect(m.todos[1].done)
}

@Test func theFirstSyncJoinsTwoPlans() throws {
    let phone = plan([todo("a", "Buy stamps")], mdp: "A 3.7 GPA")
    let tablet = plan([todo("b", "Call mum")])
    let m = try merged(base: nil, local: phone, remote: tablet)
    #expect(Set(m.todos.map(\.id)) == ["a", "b"])
    #expect(m.mdp == "A 3.7 GPA", "a goal written on one device only")
    #expect(try merged(base: nil, local: tablet, remote: phone).mdp == "A 3.7 GPA", "whichever device it was written on")
}

@Test func mergingAgainChangesNothing() throws {
    let base = plan([todo("a", "Buy stamps")])
    var phone = base, tablet = base
    phone.todos.append(todo("p", "From the phone"))
    tablet.todos[0].done = true
    let once = try merged(base: base, local: phone, remote: tablet)
    // The tablet then takes what the phone sent, with its own copy as the base.
    #expect(try merged(base: tablet, local: tablet, remote: once) == once)
    #expect(try merged(base: once, local: once, remote: once) == once)
}
