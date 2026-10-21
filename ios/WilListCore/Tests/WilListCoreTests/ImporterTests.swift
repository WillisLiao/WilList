import Foundation
import Testing
@testable import WilListCore

private let tuesday: Day = "2026-10-20"
// Feeds are read on a phone set to Los Angeles time, so UTC and New York times move.
private let la: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return c
}()

private let canvas = [
    "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Instructure//Canvas//EN",
    "BEGIN:VEVENT", "UID:event-assignment-48211", "DTSTART:20261024T035900Z", "DTEND:20261024T035900Z",
    "SUMMARY:Problem Set 6 [MATH 201 Fall 2026]", #"DESCRIPTION:Sections 4.1–4.3\, odd problems"#, "END:VEVENT",
    "BEGIN:VEVENT", "UID:event-assignment-48212", "DTSTART;VALUE=DATE:20261030", "DTEND;VALUE=DATE:20261031",
    "SUMMARY:Midterm Exam [MATH 201 Fall 2026]", "END:VEVENT",
    "BEGIN:VEVENT", "UID:event-assignment-40000", "DTSTART:20261001T035900Z", "DTEND:20261001T035900Z",
    "SUMMARY:Problem Set 1 [MATH 201 Fall 2026]", "END:VEVENT",
    "BEGIN:VEVENT", "UID:event-assignment-48213", "DTSTART:20261106T170000Z", "DTEND:20261106T170000Z",
    "SUMMARY:Essay draft: the printing press and the Reformation in Northern Eur",
    " ope [HIST 150]", "END:VEVENT",
    "END:VCALENDAR",
].joined(separator: "\r\n")

private func ics(_ s: String) -> ICSImport { importICS(s, today: tuesday, calendar: la) }

@Test func canvasFeed() {
    let r = ics(canvas)
    #expect(r.past == 1)
    #expect(r.items.count == 3)
    let ps = r.items[0]
    #expect(ps.title == "Problem Set 6")
    #expect(ps.course == "MATH201")
    #expect(ps.type == .deadline)
    #expect(ps.externalId == "ics:event-assignment-48211")
    #expect(ps.notes == "Sections 4.1–4.3, odd problems")
    // 03:59 UTC is the evening before in Los Angeles.
    #expect(ps.date == "2026-10-23" && ps.time == "20:59")
    #expect(r.items[1].type == .exam)
    #expect(r.items[1].date == "2026-10-30" && r.items[1].time == nil)
    #expect(r.items[2].title.hasSuffix("Northern Europe"))
    #expect(r.items[2].course == "HIST150")
    #expect(r.items[2].time == "09:00")
}

@Test func moodleFeed() {
    let r = ics([
        "BEGIN:VCALENDAR",
        "BEGIN:VEVENT", "UID:1234@moodle.uni.edu", "SUMMARY:Lab report 3 is due", "CATEGORIES:CHEM 110 - General Chemistry",
        "DTSTART:20261027T225900Z", "DTEND:20261027T225900Z", "END:VEVENT",
        "BEGIN:VEVENT", "UID:1235@moodle.uni.edu", "SUMMARY:Quiz 4 opens", "DTSTART:20261026T120000Z", "END:VEVENT",
        "END:VCALENDAR",
    ].joined(separator: "\n"))
    #expect(r.items.count == 1)
    #expect(r.ignored == 1)
    #expect(r.items[0].title == "Lab report 3")
    #expect(r.items[0].course == "CHEM110")
    #expect(r.items[0].type == .deadline)
}

@Test func googleClassWithZoneRuleAndException() {
    let r = ics([
        "BEGIN:VCALENDAR", "BEGIN:VEVENT", "UID:abc@google.com", "SUMMARY:Organic Chemistry Lecture",
        "DTSTART;TZID=America/New_York:20260901T100000", "DTEND;TZID=America/New_York:20260901T105000",
        "RRULE:FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=20261211T235959Z", "EXDATE;TZID=America/New_York:20261126T100000",
        "END:VEVENT", "END:VCALENDAR",
    ].joined(separator: "\r\n"))
    let ev = r.items[0]
    #expect(ev.type == .event)
    #expect(ev.recur == Recur(.weekly, days: [2, 4], until: "2026-12-11"))
    #expect(ev.durationMin == 50)
    #expect(ev.time == "07:00", "10:00 in New York")
    #expect(ev.skips == ["2026-11-26"])
}

@Test func unknownZonesKeepTheWallTime() {
    let d = icsDateTime(ICSProp(params: ["TZID": "Taipei Standard Time"], value: "20261101T093000"), calendar: la)
    #expect(d?.date == "2026-11-01" && d?.time == "09:30")
    #expect(icsDateTime(ICSProp(params: [:], value: "20261340"), calendar: la) == nil)
}

@Test func repeatRules() {
    #expect(mapRRule("FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR", start: "2026-10-19") == Recur(.weekdays))
    #expect(mapRRule("FREQ=WEEKLY;INTERVAL=2;BYDAY=FR", start: "2026-10-23") == Recur(.biweekly, days: [5]))
    #expect(mapRRule("FREQ=YEARLY", start: "2026-10-23") == nil)
    #expect(mapRRule("FREQ=WEEKLY;BYDAY=MO;COUNT=4", start: "2026-10-19")?.until == "2026-11-15")
}

@Test func courseCodes() {
    #expect(courseCode("MATH 201 Fall 2026") == "MATH201")
    #expect(courseCode("CS 50") == "CS50")
    #expect(courseCode("Intro to Psychology") == "Intro to Psychology")
}

@Test func readingAFeedAgainUpdatesInsteadOfDuplicating() {
    var s = AppState()
    s.settings = testSettings
    let first = ics(canvas)
    let plan1 = planImport(s.items, first.items)
    #expect(plan1.adds.count == 3)
    s.applyImport(plan1, today: tuesday)
    s.items[0].priority = .A
    let moved = canvas.replacingOccurrences(of: "DTSTART:20261024T035900Z", with: "DTSTART:20261026T035900Z")
    let plan2 = planImport(s.items, ics(moved).items)
    #expect(plan2.adds.isEmpty)
    #expect(plan2.updates.count == 1)
    #expect(plan2.same == 2)
    s.applyImport(plan2, today: tuesday)
    #expect(s.items.count == 3)
    #expect(s.items[0].priority == .A, "your letter survives")
    #expect(s.items[0].date == "2026-10-25")
}

@Test func gradeWeightDrivesTheSuggestedLetter() {
    #expect(suggestedLetter(.deadline, weightPct: 30) == .A)
    #expect(suggestedLetter(.exam, weightPct: 5) == .B)
    #expect(suggestedLetter(.deadline, weightPct: 1) == .C)
    #expect(suggestedLetter(.exam) == .A)
    #expect(suggestedLetter(.task) == nil)
}
