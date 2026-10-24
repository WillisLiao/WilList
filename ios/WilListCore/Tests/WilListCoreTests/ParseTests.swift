import Testing
@testable import WilListCore

// Monday 19 Oct 2026, 10:00
private func p(_ s: String, dateOrder: String = "mdy") -> Parsed {
    quickAdd(s, today: "2026-10-19", minute: 600, dateOrder: dateOrder)
}

@Test func examWithWeekdayTimeAndCourse() {
    let r = p("Calc midterm fri 2pm #MATH201")
    #expect(r.title == "Calc midterm")
    #expect(r.date == "2026-10-23")
    #expect(r.time == "14:00")
    #expect(r.course == "MATH201")
}

@Test func homeworkWithNumericDateAndDue() {
    let r = p("HW3 due 10/24 11:59pm")
    #expect(r.title == "HW3")
    #expect(r.date == "2026-10-24")
    #expect(r.time == "23:59")
}

@Test func dayFirstLocales() {
    #expect(p("Essay 24/10", dateOrder: "dmy").date == "2026-10-24")
}

@Test func weeklyMeeting() {
    let r = p("Team meeting every tue 4pm")
    #expect(r.recur == Recur(.weekly, days: [2]))
    #expect(r.date == "2026-10-20")
    #expect(r.time == "16:00")
}

@Test func timetableShorthandWithRange() {
    let r = p("Calculus lecture mwf 10-10:50am")
    #expect(r.title == "Calculus lecture")
    #expect(r.recur == Recur(.weekly, days: [1, 3, 5]))
    #expect(r.time == "10:00")
    #expect(r.durationMin == 50)
    #expect(r.date == "2026-10-19")
}

@Test func afternoonRangeWithoutStartMeridiem() {
    let r = p("Bio lab every wed 2-5pm")
    #expect(r.time == "14:00")
    #expect(r.durationMin == 180)
}

@Test func elevenToOneStartsInTheMorning() {
    let r = p("Workshop 11-1pm tomorrow")
    #expect(r.time == "11:00")
    #expect(r.durationMin == 120)
}

@Test func everyOtherWeekAndSeveralDays() {
    #expect(p("Advisor sync every other thu 3pm").recur == Recur(.biweekly, days: [4]))
    #expect(p("Gym every mon and wed 7am").recur == Recur(.weekly, days: [1, 3]))
    #expect(p("Tutoring tuesdays 5pm").recur == Recur(.weekly, days: [2]))
}

@Test func shortDayNamesAreNotRepeats() {
    let r = p("Quiz thurs")
    #expect(r.recur == nil)
    #expect(r.date == "2026-10-22")
    #expect(p("Essay due weds").recur == nil)
}

@Test func nextMondayIsNextWeek() {
    #expect(p("Read Smith 2019 paper by next mon").date == "2026-10-26")
    // On a Thursday, "next fri" is not tomorrow.
    #expect(quickAdd("Quiz next fri", today: "2026-10-22", minute: 540).date == "2026-10-30")
}

@Test func relativeDaysAndMonthNames() {
    #expect(p("Essay draft due in 2 weeks").date == "2026-11-02")
    #expect(p("Lab report due dec 5").date == "2026-12-05")
    #expect(p("Lab report due 5th dec").date == "2026-12-05")
    #expect(p("Apply for internship by jan 15").date == "2027-01-15")
    #expect(p("Pay fees tomorrow").date == "2026-10-20")
}

@Test func pastYearlessDateRollsOver() {
    #expect(p("Register 1/10").date == "2027-01-10")
}

@Test func priorityAndRank() {
    let r = p("Email TA about regrade !a2")
    #expect(r.priority == .A)
    #expect(r.rank == 2)
    #expect(r.title == "Email TA about regrade")
}

@Test func atThreeMeansAfternoon() {
    #expect(p("Office hours thu at 3").time == "15:00")
}

@Test func timeWithoutDateLandsTodayOrTomorrow() {
    #expect(p("Call mom 6pm").date == "2026-10-19")
    #expect(p("Call mom 8am").date == "2026-10-20")
}

@Test func durationIsRead() {
    let r = p("Study 2h for chem quiz on oct 22")
    #expect(r.durationMin == 120)
    #expect(r.title == "Study for chem quiz")
}

@Test func unknownWordsStayInTheTitle() {
    let r = p("Problem set 5")
    #expect(r.title == "Problem set 5")
    #expect(p("constructor toString").title == "constructor toString")
}

@Test func victimLanguageHints() {
    #expect(p("I will try to finish chapter 3 tonight").hints == [.tryTo])
    #expect(p("I’ll try to call").hints == [.tryTo])
    #expect(p("I have to do laundry").hints.contains(.haveTo))
    #expect(p("Fix wifi problem").hints.contains(.problem))
    #expect(p("Problem set 5").hints.isEmpty)
}

@Test func typedWordsAreAlwaysATask() {
    // No exams, deadlines, readings, talks, classes or study blocks read from the words, and no
    // share of the grade: "ML test" once became an undated exam that Plan put under Later.
    for s in ["ML test", "Calc midterm fri 2pm", "Essay due fri", "Read ch 4", "Group presentation thu",
              "Team meeting every tue 4pm", "Study chem tue 7pm 2h"] {
        #expect(Item(p(s)).type == .task)
    }
    #expect(p("Lab report worth 25%").title == "Lab report worth 25%")
}

@Test func hugeNumbersStayInTheTitle() {
    #expect(p("Plan in 99999999999999999999 days").date == nil)
    #expect(p("Read 99999999999999999999h").durationMin == nil)
}
