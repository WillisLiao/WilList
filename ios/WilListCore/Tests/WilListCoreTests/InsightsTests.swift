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
