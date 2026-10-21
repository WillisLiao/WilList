import Testing
@testable import WilListCore

let testSettings: Settings = {
    var s = Settings()
    s.sessionMin = 50
    s.perDayMin = 120
    s.bufferDays = 1
    return s
}()
let monday: Day = "2026-10-19"

func draft(_ title: String, _ type: ItemType, date: Day? = nil, effort: Int = 0, priority: Letter? = nil,
           recur: Recur? = nil, time: String? = nil, sessions: [Session] = []) -> Item {
    var it = Item(id: "", title: title, type: type)
    it.date = date
    it.effortMin = effort
    it.priority = priority
    it.recur = recur
    it.time = time
    it.sessions = sessions
    return it
}

private func plan(_ type: ItemType, _ date: Day, _ effort: Int, sessions: [Session] = [], load: [Day: Int] = [:]) -> PlanResult {
    buildPlan(draft("Thing", type, date: date, effort: effort, sessions: sessions), testSettings, monday, load: load)
}

@Test func examSessionsEndTheDayBefore() {
    let r = plan(.exam, "2026-10-31", 480)
    let dates = r.sessions.map(\.date)
    #expect(dates.allSatisfy { $0 < "2026-10-31" })
    #expect(dates.last == "2026-10-30")
    #expect(r.startBy == dates.first)
    #expect(diffDays(monday, r.startBy!) >= 0)
    #expect(r.shortfallMin == 0)
    let total = r.sessions.reduce(0) { $0 + $1.minutes }
    #expect(total >= 480 && total < 530)
}

@Test func examSessionsAreSpaced() {
    // 3 sessions over a month: expanding gaps back from the day before.
    let r = plan(.exam, "2026-11-20", 150)
    #expect(r.sessions.map(\.date) == ["2026-11-16", "2026-11-18", "2026-11-19"])
    #expect(r.sessions.last!.label.contains("Light review"))
}

@Test func smallEffortIsNotInflated() {
    let r = plan(.reading, "2026-10-25", 120)
    #expect(r.sessions.count == 2)
    #expect(r.sessions[0].minutes == 60)
}

@Test func deadlinesFinishABufferDayEarly() {
    let r = plan(.deadline, "2026-10-25", 180)
    #expect(r.sessions.allSatisfy { $0.date <= "2026-10-24" })
    #expect(r.sessions.last!.label.lowercased().contains("submit"))
}

@Test func notEnoughTimeReportsAShortfall() {
    let r = plan(.exam, "2026-10-20", 900)
    #expect(r.sessions.count == 2)
    #expect(r.sessions.allSatisfy { $0.date == monday })
    #expect(r.shortfallMin > 0)
    #expect(r.sessions.reduce(0) { $0 + $1.minutes } <= testSettings.perDayMin)
}

@Test func examTodayHasNoSessionsLeft() {
    let r = plan(.exam, monday, 300)
    #expect(r.sessions.isEmpty)
    #expect(r.shortfallMin == 300)
}

@Test func replanningKeepsFinishedSessions() {
    let done = Session(id: "x", date: "2026-10-15", minutes: 60, label: "old", done: true)
    let r = plan(.exam, "2026-10-30", 240, sessions: [done])
    #expect(r.sessions[0] == done)
    let fresh = r.sessions.filter { !$0.done }
    #expect(fresh.reduce(0) { $0 + $1.minutes } == 180)
    #expect(fresh.allSatisfy { $0.date >= monday })
}

@Test func effortSuggestions() {
    #expect(suggestEffort(.exam, "Chem quiz") == 120)
    #expect(suggestEffort(.exam, "Calc final") == 900)
    #expect(suggestEffort(.deadline, "History essay") == 600)
    #expect(suggestEffort(.task, "Laundry") == 0)
}

@Test func plansAroundStudyAlreadyBooked() {
    // Today and tomorrow are already full; a 2-session job should land elsewhere.
    let r = plan(.deadline, "2026-10-26", 100, load: ["2026-10-19": 120, "2026-10-20": 120])
    #expect(r.sessions.count == 2)
    #expect(r.sessions.allSatisfy { $0.date > "2026-10-20" })
}

@Test func overbooksOnlyWithNoFreeDayLeft() {
    let r = plan(.deadline, monday, 50, load: [monday: 120])
    #expect(r.sessions.count == 1)
    #expect(r.sessions[0].date == monday)
    #expect(r.shortfallMin == 0)
}

@Test func datesRoundTrip() {
    #expect(addDays("2026-12-31", 1) == "2027-01-01")
    #expect(addDays("2024-03-01", -1) == "2024-02-29")
    #expect(diffDays("2026-10-19", "2026-11-02") == 14)
    #expect(weekday("2026-10-19") == 1)
    #expect(weekStart("2026-10-25") == "2026-10-19")
    #expect(makeDay(2026, 2, 30) == nil)
    #expect(isValidDay("2026-02-28") && !isValidDay("2026-2-28"))
    #expect(minToTime(-30) == "23:30")
}
