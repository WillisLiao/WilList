import Testing
@testable import WilListCore

private func ev(_ time: String, _ minutes: Int, _ title: String = "Class") -> Item {
    var it = Item(id: title, title: title, type: .event)
    it.time = time
    it.durationMin = minutes
    return it
}

private func row(_ label: String, _ priority: Letter, _ minutes: Int) -> Row {
    var it = Item(id: label, title: label)
    it.priority = priority
    var r = Row(item: it, session: minutes > 0 ? Session(id: "\(label)s", date: "2026-10-19", minutes: minutes, label: "") : nil)
    r.label = label
    return r
}

private func work(_ p: DayPlan) -> [String] {
    p.slots.filter { $0.kind == .work }.map { s in
        "\(s.row!.label)@\(minToTime(s.start))-\(minToTime(s.end))\(s.part.map { "#\($0)" } ?? "")"
    }
}

@Test func workFillsTheGapsBetweenClasses() {
    let r = planDay(events: [ev("10:00", 50), ev("14:00", 180, "Lab")],
                    rows: [row("A1", .A, 60), row("A2", .A, 0), row("B1", .B, 45)], nowMin: 9 * 60)
    #expect(work(r) == ["A2@09:00-09:25", "A1@10:55-11:55", "B1@12:05-12:50"])
    #expect(r.unplaced.isEmpty)
    #expect(r.slots.filter { $0.kind == .event }.count == 2)
}

@Test func bigBlocksSplitAcrossGaps() {
    let r = planDay(events: [ev("09:00", 60), ev("11:00", 60)], rows: [row("A1", .A, 150)], dayStart: "07:55", dayEnd: "13:00")
    #expect(work(r) == ["A1@07:55-08:55#1", "A1@10:05-10:55#2", "A1@12:05-12:45#3"])
}

@Test func whatDoesNotFitIsReported() {
    let r = planDay(events: [], rows: [row("A1", .A, 300), row("D1", .D, 30), row("E1", .E, 30)], dayStart: "20:00", dayEnd: "22:00")
    #expect(r.unplaced.count == 1)
    #expect(r.unplaced[0].row.label == "A1")
    #expect(!work(r).contains { $0.hasPrefix("D") || $0.hasPrefix("E") })
}

@Test func nothingIsPlannedInThePast() {
    #expect(work(planDay(events: [], rows: [row("A1", .A, 30)], nowMin: 15 * 60 + 2))[0] == "A1@15:05-15:35")
}

@Test func studyBlocksAreFixedTimeAndCountAsStudy() {
    let monday = "2026-10-19"
    // As Plan's New study block adds it: the words give the time, the menu the kind.
    let p = quickAdd("Organic chem every tue thu 7pm 2h", today: monday, minute: 9 * 60)
    #expect(p.time == "19:00" && p.recur?.days == [2, 4])
    var draft = Item(p)
    draft.type = .study
    let block = makeItem(draft, Settings(), monday)
    #expect(block.durationMin == 120)
    let tuesday = addDays(monday, 1)
    #expect(scheduleOn([block], tuesday).map(\.id) == [block.id])
    // Not a line of the day's list; Plan lists it under Later, where it can be changed any day.
    #expect(dayRows([block], tuesday).isEmpty && laterItems([block], tuesday).map(\.id) == [block.id])
    #expect(radar([block], monday, days: 3, perDayMin: 120).map(\.load) == [0, 120, 0])
    // Ticked off on Tuesday, it is done for that day only.
    var s = AppState()
    s.items = [block]
    s.completeLater(block.id, today: tuesday)
    #expect(s.items[0].doneDates == [tuesday] && !s.items[0].done)
}
