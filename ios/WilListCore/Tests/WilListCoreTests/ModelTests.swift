import Foundation
import Testing
@testable import WilListCore

let testSettings: Settings = {
    var s = Settings()
    s.perDayMin = 120
    return s
}()
let monday: Day = "2026-10-19"

func draft(_ title: String, _ type: ItemType = .task, date: Day? = nil, priority: Letter? = nil,
           recur: Recur? = nil, time: String? = nil) -> Item {
    var it = Item(id: "", title: title, type: type)
    it.date = date
    it.priority = priority
    it.recur = recur
    it.time = time
    return it
}

@Test func olderKindsLoadAsTasks() throws {
    // An exam with its study sessions, a class and a study block, as older saves (and the website) wrote them.
    let old = #"{"v":1,"items":[{"id":"a","title":"Calc midterm","type":"exam","date":"2026-10-23","effortMin":480,"priority":"A","sessions":[{"id":"s","date":"2026-10-20","minutes":50,"label":"Recall"}]},{"id":"b","title":"Lecture","type":"event","time":"10:00","durationMin":50},{"id":"c","title":"Chem","type":"study","date":"2026-10-20","time":"19:00","durationMin":90}]}"#
    let s = try JSONDecoder().decode(AppState.self, from: Data(old.utf8))
    #expect(s.items.map(\.type) == [.task, .task, .study])
    #expect(s.items[0].date == "2026-10-23" && s.items[0].priority == .A)
    #expect(dayRows(s.items, monday).map(\.item.title) == ["Calc midterm"])
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

@Test func coursesKeepTheirOwnColours() throws {
    var s = AppState()
    for (title, course) in [("Problem set", "MATH201"), ("Quiz", "CHEM110"), ("Lab", "chem110 "), ("Essay", "HIST150"), ("Call home", nil)] {
        var it = Item(id: title, title: title)
        it.course = course
        s.items.append(it)
    }
    s.colorCourses()
    #expect(s.settings.courseColors == ["math201": 0, "chem110": 1, "hist150": 2])
    #expect(s.courseColor("CHEM110") == 1)
    #expect(s.courseColor(nil) == nil)

    // A course that goes gives its colour back; the others keep theirs.
    s.items.removeAll { $0.course == "MATH201" }
    var read = Item(id: "Read", title: "Read")
    read.course = "BIO100"
    s.items.append(read)
    s.colorCourses()
    #expect(s.settings.courseColors == ["bio100": 0, "chem110": 1, "hist150": 2])

    // An older save has none: they're given on loading, and a broken map doesn't stop it loading.
    let old = #"{"v":1,"items":[{"id":"a","title":"Essay","course":"ENG101"}],"settings":{"courseColors":{"eng101":99}}}"#
    let loaded = try JSONDecoder().decode(AppState.self, from: Data(old.utf8))
    #expect(loaded.settings.courseColors == ["eng101": 0])
}
