import Testing
@testable import WilListCore

private let tuesday: Day = "2026-10-20"

@Test func calibrationNeedsThreeSessions() {
    var s = AppState()
    func add(_ minutes: Double, _ planned: Int) {
        s.logFocus(itemId: "x", type: .deadline, title: "PS", minutes: minutes, planned: planned, completed: true, today: tuesday)
    }
    add(70, 50)
    add(65, 50)
    #expect(calibration(s.log, .deadline) == nil)
    add(75, 50)
    #expect(calibration(s.log, .deadline) == Calibration(type: .deadline, ratio: 1.4, n: 3, label: "Homework"))
    #expect(calibrations(s.log).first?.type == .deadline)
    #expect(calibrations(s.log, current: ["deadline": 1.4]).isEmpty, "no suggestion once accepted")
    add(0.4, 50)
    #expect(s.log.count == 3, "sub-minute sessions are not logged")
}

@Test func acceptedCalibrationScalesEstimates() {
    var settings = testSettings
    settings.calib = ["deadline": 1.5]
    let it = makeItem(draft("Problem set 7", .deadline, date: "2026-10-30"), settings, tuesday)
    #expect(it.effortMin == 270)
}

@Test func a1FirstStreak() {
    #expect(a1Streak(["2026-10-17": "A", "2026-10-18": "B", "2026-10-19": "A", "2026-10-20": "A"], tuesday) == 2)
    #expect(a1Streak(["2026-10-19": "A"], tuesday) == 1, "today not started yet still counts yesterday")
    #expect(a1Streak(["2026-10-20": "C", "2026-10-19": "A"], tuesday) == 0)
}

@Test func firstFinishedItemRecordsItsLetter() {
    var s = AppState()
    s.items = [makeItem(draft("B thing", .task, priority: .B), testSettings, tuesday),
               makeItem(draft("A thing", .task, priority: .A), testSettings, tuesday)]
    s.complete(itemId: s.items[0].id, today: tuesday)
    s.complete(itemId: s.items[1].id, today: tuesday)
    #expect(s.meta.firstDone[tuesday] == "B")
    let w = s.weekStats(tuesday)
    #expect(w.done == 2)
    #expect(w.aDone == 1)
    #expect(w.aFirstDays == 0)
}

@Test func doneByDayCountsEachKindOnItsDay() {
    var s = AppState()
    var a = makeItem(draft("Essay", .task, priority: .A), testSettings, tuesday)
    a.done = true
    a.doneAt = tuesday
    var call = makeItem(draft("Call home", .task, date: "2026-10-18", priority: .B, recur: Recur(.daily)), testSettings, tuesday)
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
    var final = makeItem(draft("Chem final", .exam, date: addDays(tuesday, 10), priority: .A), testSettings, tuesday)
    final.sessions = []
    var old = makeItem(draft("Tidy desk", .task, priority: .D), testSettings, addDays(tuesday, -20))
    old.createdAt = addDays(tuesday, -20)
    s.items = [final, old, makeItem(draft("Email TA", .task), testSettings, tuesday)]
    let found = suggestions(s, tuesday)
    #expect(found.contains(.startEarly(final)))
    #expect(found.contains(.review(ids: [old.id])))
    #expect(found.firstIndex(of: .startEarly(final))! < found.firstIndex(of: .review(ids: [old.id]))!)
}
