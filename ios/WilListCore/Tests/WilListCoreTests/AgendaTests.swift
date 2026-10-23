import Foundation
import Testing
@testable import WilListCore

private func mk(_ title: String, _ type: ItemType, date: Day? = nil, effort: Int = 0, priority: Letter? = nil,
                recur: Recur? = nil, time: String? = nil, items: [Item] = []) -> Item {
    makeItem(draft(title, type, date: date, effort: effort, priority: priority, recur: recur, time: time), testSettings, monday, items)
}

private func on(_ start: Day, _ recur: Recur, skips: [Day] = []) -> Item {
    var it = draft("Thing", .event, date: start, recur: recur)
    it.skips = skips
    return it
}

private func state(_ items: Item...) -> AppState {
    var s = AppState()
    s.settings = testSettings
    s.items = items
    return s
}

@Test func recurrence() {
    let weekly = on("2026-10-19", Recur(.weekly, days: [1, 3]))
    #expect(occursOn(weekly, "2026-10-21"))
    #expect(!occursOn(weekly, "2026-10-20"))
    #expect(!occursOn(weekly, "2026-10-12"), "not before the start date")
    let bi = on("2026-10-20", Recur(.biweekly, days: [2]))
    #expect(occursOn(bi, "2026-11-03"))
    #expect(!occursOn(bi, "2026-10-27"))
    let wd = on("2026-10-19", Recur(.weekdays))
    #expect(occursOn(wd, "2026-10-23") && !occursOn(wd, "2026-10-24"))
    let mo = on("2026-10-05", Recur(.monthly))
    #expect(occursOn(mo, "2026-11-05") && !occursOn(mo, "2026-11-06"))
    #expect(!occursOn(on("2026-10-19", Recur(.daily), skips: ["2026-10-20"]), "2026-10-20"))
}

@Test func unletteredItemsWaitToBeSorted() {
    let t = mk("Buy groceries", .task)
    #expect(dayRows([t], monday).isEmpty)
    #expect(unsorted([t], monday).count == 1)
}

@Test func listIsOrderedByLetterNotDueDate() {
    let urgentC = mk("Return library book", .task, date: monday, priority: .C)
    let importantA = mk("Essay", .task, date: "2026-10-28", priority: .A)
    let rows = dayRows([urgentC, importantA], monday)
    #expect(rows.map(\.label) == ["A1", "C1"])
    #expect(rows[0].item.title == "Essay")
}

@Test func importantExamsSurfaceThroughTodaysSession() {
    let exam = mk("Calc midterm", .exam, date: "2026-10-23", effort: 240, priority: .A)
    let rows = dayRows([exam], monday)
    #expect(!rows.isEmpty)
    #expect(rows.allSatisfy { $0.session != nil })
    #expect(importantNotUrgent([exam], monday).count == 1)
}

@Test func futureSessionsStayOffToday() {
    let exam = mk("Final", .exam, date: "2026-12-10", effort: 150, priority: .A)
    #expect(dayRows([exam], monday).isEmpty)
    #expect(!dayRows([exam], exam.sessions[0].date).isEmpty)
}

@Test func lastSessionOfADeadlineCompletesIt() {
    let hw = mk("Problem set", .deadline, date: "2026-10-21", effort: 50, priority: .A)
    var s = state(hw)
    #expect(hw.sessions.count == 1)
    let finished = s.complete(itemId: hw.id, sessionId: hw.sessions[0].id, today: hw.sessions[0].date)
    #expect(finished)
    #expect(s.items[0].done)
}

@Test func dueTodayDeadlineShowsOnce() {
    let hw = mk("Lab report", .deadline, date: monday, effort: 100, priority: .A)
    let rows = dayRows([hw], monday)
    #expect(rows.count == 1)
    #expect(rows[0].session == nil)
}

@Test func repeatingTasksCompletePerDay() {
    var s = state(mk("Review flashcards", .task, date: monday, priority: .B, recur: Recur(.daily)))
    let rows = dayRows(s.items, monday)
    #expect(rows.count == 1)
    s.complete(rows[0], today: monday)
    #expect(dayRows(s.items, monday).isEmpty)
    #expect(dayRows(s.items, "2026-10-20").count == 1)
}

@Test func reRankingSwapsA1AndA2() {
    var s = state(mk("First", .task, date: "2026-10-20", priority: .A), mk("Second", .task, date: "2026-10-22", priority: .A))
    var rows = dayRows(s.items, monday)
    #expect(rows[0].item.title == "First")
    s.move(rows, key: rows[1].key, by: -1)
    rows = dayRows(s.items, monday)
    #expect(rows[0].item.title == "Second")
    #expect(rows[0].label == "A1")
}

@Test func theSameLetterAgainKeepsItsPlace() {
    var s = state(mk("Essay", .task), mk("Lab", .task))
    s.setLetter(s.items[0].id, .A)
    s.setLetter(s.items[1].id, .A)
    s.makeA1(s.items[1].id, today: monday)
    s.setLetter(s.items[1].id, .A)
    #expect(dayRows(s.items, monday).map(\.item.title) == ["Lab", "Essay"])
}

@Test func settingALetterMovesItOutOfTheTray() {
    var s = state(mk("Email professor", .task))
    s.setLetter(s.items[0].id, .A)
    #expect(unsorted(s.items, monday).isEmpty)
    #expect(dayRows(s.items, monday)[0].label == "A1")
}

@Test func scheduleMergesByTime() {
    let cls = mk("Lecture", .event, date: monday, recur: Recur(.weekly, days: [1]), time: "10:00")
    let exam = mk("Quiz", .exam, date: monday, time: "09:00")
    #expect(scheduleOn([cls, exam], monday).map(\.title) == ["Quiz", "Lecture"])
    #expect(isPast(exam, "2026-10-20"))
    #expect(!isPast(cls, "2026-10-20"))
}

@Test func radarFlagsOverloadAndStartDays() {
    let a = mk("Exam A", .exam, date: "2026-10-21", effort: 240, priority: .A)
    let b = mk("Exam B", .exam, date: "2026-10-21", effort: 240, priority: .A)
    let days = radar([a, b], monday, days: 3, perDayMin: 120)
    #expect(days.contains { $0.over })
    #expect(!days[0].starts.isEmpty)
}

@Test func vitalFewReportsProgress() {
    let exam = mk("Midterm", .exam, date: "2026-10-30", effort: 240, priority: .A)
    var s = state(exam)
    let v = vitalFew(s.items, monday)[0]
    #expect(v.total == exam.sessions.count)
    #expect(v.done == 0)
    // Missing a session marks it behind; replanning fixes that.
    let dayAfter: Day = "2026-10-29"
    #expect(vitalFew(s.items, dayAfter)[0].status == (exam.sessions[0].date < dayAfter ? .behind : .onTrack))
    s.replan(exam.id, today: dayAfter)
    #expect(vitalFew(s.items, dayAfter)[0].status != .behind)
}

@Test func oneRowPerItemEvenWithSeveralSessionsDue() {
    let exam = mk("Big final", .exam, date: "2026-10-21", effort: 400, priority: .A)
    let rows = dayRows([exam], monday)
    #expect(rows.count == 1)
    #expect(rows[0].extra >= 1)
}

@Test func lookingAtTomorrowCarriesTodayOver() {
    var hw = mk("Essay", .deadline, date: "2026-10-24", effort: 50, priority: .A)
    hw.sessions[0].date = monday
    #expect(dayRows([hw], "2026-10-20", realToday: monday)[0].overdue == false)
    #expect(dayRows([hw], "2026-10-20")[0].overdue == true)
}

@Test func balancingGivesAsFirstClaim() {
    // The B was added first and took the free study time; the A arrived later and got pushed aside.
    var s = state(mk("B reading", .reading, date: "2026-10-21", effort: 200, priority: .B))
    s.items.append(mk("A exam", .exam, date: "2026-10-27", effort: 240, priority: .A, items: s.items))
    let alone = buildPlan(draft("Thing", .exam, date: "2026-10-27", effort: 240), testSettings, monday).sessions.map(\.date)
    #expect(s.items[1].sessions.map(\.date) != alone, "precondition: the B pushed the A off its best days")
    s.replanAll(today: monday)
    #expect(s.items[1].sessions.map(\.date) == alone)
    #expect(s.items[1].shortfallMin == 0)
}

@Test func delegatedAndEliminatedGetNoSessions() {
    var s = state(mk("Group poster", .deadline, date: "2026-10-28", effort: 180))
    #expect(!s.items[0].sessions.isEmpty)
    s.setLetter(s.items[0].id, .D, today: monday)
    #expect(s.items[0].sessions.isEmpty)
    s.setLetter(s.items[0].id, .A, today: monday)
    #expect(!s.items[0].sessions.isEmpty)
}

@Test func oldSavesLoadAndJunkRowsAreDropped() throws {
    let json = """
    {"items":[{"id":"a","title":"Essay","type":"deadline","date":"2026-10-24","priority":"A","order":9.5e6,
      "effortMin":180.0,"sessions":[{"id":"s1","date":"2026-10-20","minutes":60,"label":"Start","done":false},{"bad":1}],
      "recur":null,"weightPct":20,"mystery":true},{"title":"no id"}],
     "todos":[{"id":"t1","title":"Buy stamps","done":false,"doneAt":null},null,{"id":2},"x"],
     "settings":{"perDayMin":90,"calib":{"deadline":1.5},"todayMode":"list"},
     "meta":{"firstDone":{"2026-10-19":"A"},"fired":{}},
     "worries":[{"text":"rent","plan":["call"]}],"coach":{"messages":[]},"exercise":{"0":"Graduate"}}
    """
    let s = try JSONDecoder().decode(AppState.self, from: Data(json.utf8))
    #expect(s.items.count == 1)
    #expect(s.items[0].effortMin == 180)
    #expect(s.items[0].sessions.count == 1)
    #expect(s.items[0].priority == .A)
    #expect(s.todos == [Todo(id: "t1", title: "Buy stamps")])
    #expect(s.settings.perDayMin == 90 && s.settings.sessionMin == 50)
    #expect(s.settings.calib["deadline"] == 1.5)
    #expect(s.meta.firstDone["2026-10-19"] == "A")
    #expect(s.exercise["0"] == "Graduate")
    // What the app does not use itself comes back out unchanged.
    let again = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(s))
    #expect(again == s)
    #expect(again.worries.count == 1 && again.coach != nil)
}

@Test func todos() {
    var s = AppState()
    s.addTodo("  Buy stamps ", today: monday)
    s.addTodo("   ", today: monday)
    #expect(s.todos.map(\.title) == ["Buy stamps"])
    s.toggleTodo(s.todos[0].id, today: monday)
    #expect(s.todos[0].done && s.todos[0].doneAt == monday)
    s.toggleTodo(s.todos[0].id, today: monday)
    #expect(!s.todos[0].done && s.todos[0].doneAt == nil)
    s.removeTodo(s.todos[0].id)
    #expect(s.todos.isEmpty)
}

@Test func aTodoThatMattersMovesIntoThePlan() throws {
    var s = AppState()
    var t = Todo(id: "t", title: "Email the TA")
    t.date = monday
    t.time = "17:00"
    t.remindAt = "2026-10-19T16:00"
    t.steps = [Step(id: "s", title: "Find the quiz", done: true)]
    t.notes = "Quiz 3"
    s.todos = [t, Todo(id: "u", title: "Buy stamps")]
    let result = s.letterTodo("t", .A, today: monday)
    let moved = try #require(result)
    #expect(s.todos.map(\.id) == ["u"])
    #expect(s.items == [moved])
    #expect(moved.title == "Email the TA" && moved.type == .task && moved.priority == .A)
    #expect(moved.date == monday && moved.time == "17:00" && moved.remindAt == "2026-10-19T16:00")
    #expect(moved.steps == t.steps && moved.notes == "Quiz 3" && moved.myDay == monday)
    #expect(doRows(s.items, monday).first?.item.id == moved.id, "it is the A1 now")
    let gone = s.letterTodo("gone", .B, today: monday)
    #expect(gone == nil)
}

@Test func theOneThatMattersMostBecomesTheA1() {
    var s = AppState()
    for (title, letter) in [("Essay", Letter.A), ("Lab", .A), ("Email", .B)] {
        var it = makeItem(Item(id: "", title: title), s.settings, monday, s.items)
        it.priority = letter
        s.items.append(it)
    }
    let email = s.items[2].id, lab = s.items[1].id
    s.makeA1(email, today: monday)
    #expect(doRows(s.items, monday).map(\.item.title) == ["Email", "Essay", "Lab"])
    #expect(doRows(s.items, monday).first?.label == "A1")
    s.makeA1(lab, today: monday)
    #expect(doRows(s.items, monday).map(\.label) == ["A1", "A2", "A3"])
    #expect(doRows(s.items, monday).first?.item.title == "Lab")
    s.makeA1("gone", today: monday)
    #expect(doRows(s.items, monday).first?.item.title == "Lab")
}

@Test func todoDatesAndRepeats() throws {
    var s = AppState()
    let added = s.addTodo("Call mum tomorrow 6pm", today: monday, minute: 600)
    let call = try #require(added)
    #expect(call.title == "Call mum" && call.date == "2026-10-20" && call.time == "18:00")
    let stamps = s.addTodo("Buy stamps", today: monday, onTop: true)
    let plain = try #require(stamps)
    #expect(plain.date == nil && plain.time == nil && s.todos.first == plain && plain.createdAt == monday)

    var t = Todo(id: "w", title: "Water plants")
    t.date = monday
    t.recur = Recur(.weekly, days: [1])
    t.remindAt = "2026-10-19T08:00"
    t.steps = [Step(id: "s", title: "Fern", done: true)]
    s.todos = [t]
    s.toggleTodo("w", today: monday)
    try #require(s.todos.count == 2)
    let next = s.todos[1]
    #expect(s.todos[0].done && !next.done && next.date == "2026-10-26" && next.remindAt == "2026-10-26T08:00")
    #expect(next.steps.map(\.title) == ["Fern"] && next.steps.map(\.done) == [false])
    s.toggleTodo("w", today: monday)
    #expect(s.todos.map(\.id) == ["w"] && !s.todos[0].done, "ticking it back on takes the next one away")
    // Ticked weeks late, the next one is still not in the past.
    s.toggleTodo("w", today: "2026-11-11")
    #expect(s.todos[1].date == "2026-11-16")

    // With date recognition off, the line stays exactly as typed.
    let literal = s.addTodo("Read chapter 5 friday", today: monday, readDates: false)
    #expect(literal?.title == "Read chapter 5 friday" && literal?.date == nil)

    // Items keep a reminder, steps and the day they were added to Today.
    var item = Item(id: "i", title: "Lab report")
    item.remindAt = "2026-10-20T09:00"
    item.steps = [Step(id: "a", title: "Graphs")]
    item.myDay = monday
    #expect(try JSONDecoder().decode(Item.self, from: JSONEncoder().encode(item)) == item)

    // An older save without any of the new fields still reads.
    let old = try JSONDecoder().decode(Todo.self, from: Data(#"{"id":"t","title":"Old","done":true,"doneAt":"2026-10-01"}"#.utf8))
    #expect(old.done && old.date == nil && old.steps.isEmpty && !old.starred && old.notes.isEmpty)
}

@Test func repeatsEveryFewAndYearly() {
    #expect(repeats(Recur(.daily, interval: 3), from: monday, on: addDays(monday, 6)))
    #expect(!repeats(Recur(.daily, interval: 3), from: monday, on: addDays(monday, 4)))
    #expect(repeats(Recur(.yearly), from: "2024-02-10", on: "2026-02-10"))
    #expect(!repeats(Recur(.yearly, interval: 2), from: "2024-02-10", on: "2025-02-10"))
    #expect(repeats(Recur(.monthly, interval: 2), from: "2026-01-15", on: "2026-03-15"))
    #expect(!repeats(Recur(.monthly, interval: 2), from: "2026-01-15", on: "2026-02-15"))
    #expect(repeats(Recur(.weekly, interval: 3), from: monday, on: addDays(monday, 21)), "no days given: the start's weekday")
    #expect(!repeats(Recur(.weekly, interval: 3), from: monday, on: addDays(monday, 14)))
    #expect(nextRepeat(Recur(.weekdays), from: "2026-10-23", after: "2026-10-23") == "2026-10-26")
    #expect(nextRepeat(Recur(.daily, until: "2026-10-20"), from: monday, after: "2026-10-20") == nil)
    #expect(shiftReminder("2026-10-19T08:30", by: 7) == "2026-10-26T08:30")
}

@Test func studyTodayAndReadiness() {
    let exam = mk("Calc midterm", .exam, date: "2026-10-21", effort: 200)
    let dropped = mk("Old reading", .reading, date: "2026-10-22", effort: 60, priority: .E)
    let essay = mk("Essay", .deadline, date: "2026-12-10", effort: 120, priority: .A)
    let rows = studyRows([essay, exam, dropped], monday)
    #expect(rows.map(\.item.title) == ["Calc midterm"], "unlettered work counts; dropped and future work does not")
    #expect(rows[0].extra >= 1)
    #expect(readiness([essay, exam, dropped], monday).map(\.item.title) == ["Calc midterm"], "45-day horizon, nothing dropped")
    #expect(readiness([essay, exam], monday, horizon: 60).map(\.item.title) == ["Calc midterm", "Essay"])
    #expect(vitalFew([essay, exam], monday, horizon: 60).map(\.item.title) == ["Essay"])
}
